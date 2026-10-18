// We use a global audio queue to manage mixing.

use std::cell::RefCell;
use std::collections::{HashMap, VecDeque};

use vectarine_plugin_sdk::sdl2;
use vectarine_plugin_sdk::sdl2::Sdl;

/// How much sound is mixed ahead of what plays: frames can take this long without the sound breaking up (a level
/// loading). Sounds started now are heard after at most this delay.
static DURATION_OF_BUFFER_IN_MS: f32 = 150.0;

/// A fade of the volume, applied while the sound plays (never written into the sound itself, so that a looped sound
/// doesn't fade again at every repetition).
#[derive(Debug, Clone, Copy, Default)]
pub struct Fade {
    /// Length of the fade, in samples
    pub total: usize,
    /// Samples of the fade already played
    pub done: usize,
}

impl Fade {
    fn new(total: usize) -> Option<Self> {
        if total == 0 {
            None
        } else {
            Some(Self { total, done: 0 })
        }
    }
    /// From 0 to 1 over the fade
    fn progress(&self) -> f32 {
        (self.done as f32 / self.total as f32).min(1.0)
    }
}

pub struct AudioResourceBuffer {
    pub buffer: VecDeque<f32>,
    pub progress: usize, // How many samples have been played
    pub is_playing: bool,
    pub volume: f32,
    pub is_looped: bool,
    /// The volume rising from silence when the sound starts or resumes
    pub fade_in: Option<Fade>,
    /// The volume going down to silence before the sound pauses
    pub fade_out: Option<Fade>,
    /// Samples at the end of a sound that is not looped which fade to silence (so that a sound cut short doesn't click)
    pub end_fade: usize,
}

impl Default for AudioResourceBuffer {
    fn default() -> Self {
        Self {
            buffer: VecDeque::new(),
            progress: 0,
            is_playing: false,
            is_looped: false,
            volume: 1.0,
            fade_in: None,
            fade_out: None,
            end_fade: 0,
        }
    }
}

impl AudioResourceBuffer {
    /// Clear the buffer and reset the state of the audio resource.
    pub fn clear(&mut self) {
        self.buffer.clear();
        self.progress = 0;
        self.is_playing = false;
        self.fade_in = None;
        self.fade_out = None;
    }

    /// The volume of the next sample, with the fades. Advances the fades.
    fn next_gain(&mut self) -> f32 {
        let mut gain = self.volume;
        if let Some(fade) = &mut self.fade_in {
            gain *= fade.progress();
            fade.done += 1;
            if fade.done >= fade.total {
                self.fade_in = None;
            }
        }
        if let Some(fade) = &mut self.fade_out {
            gain *= 1.0 - fade.progress();
            fade.done += 1;
            if fade.done >= fade.total {
                self.fade_out = None;
                self.is_playing = false;
            }
        }
        if !self.is_looped && self.end_fade > 0 {
            let left = self.buffer.len().saturating_sub(self.progress);
            if left < self.end_fade {
                gain *= left as f32 / self.end_fade as f32;
            }
        }
        gain
    }
}

// Invariant: ChannelId refers to an index in the audio_buffers vector of the AudioQueue.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ChannelId(usize);

pub struct AudioQueue {
    /// The device sound goes to. None when there is no audio device, or when the game runs headless (automated
    /// tests): sounds still load and keep their state, but nothing is heard.
    pub audio_queue: Option<sdl2::audio::AudioQueue<f32>>,
    pub audio_buffers: HashMap<ChannelId, AudioResourceBuffer>,
}

impl AudioQueue {
    pub fn new(audio_queue: Option<sdl2::audio::AudioQueue<f32>>) -> Self {
        Self {
            audio_queue,
            audio_buffers: HashMap::new(),
        }
    }
    /// Mix the next `samples_to_advance` samples (interleaved stereo) of every sound playing.
    pub fn mix_audio(&mut self, samples_to_advance: usize) -> Vec<f32> {
        let mut output = vec![0.0; samples_to_advance];

        for buffer in self.audio_buffers.values_mut() {
            if buffer.progress >= buffer.buffer.len() {
                if buffer.is_looped {
                    buffer.progress = 0;
                } else {
                    buffer.is_playing = false;
                }
            }
            if buffer.buffer.is_empty() {
                continue;
            }

            for output_sample in output.iter_mut() {
                if !buffer.is_playing {
                    break;
                }
                let sample = *buffer.buffer.get(buffer.progress).unwrap_or(&0.0);
                *output_sample += sample * buffer.next_gain();
                if buffer.is_looped {
                    // branch prediction makes this basically free.
                    buffer.progress = (buffer.progress + 1).rem_euclid(buffer.buffer.len());
                } else {
                    buffer.progress = std::cmp::min(buffer.progress + 1, buffer.buffer.len());
                    if buffer.progress >= buffer.buffer.len() {
                        buffer.is_playing = false;
                    }
                }
            }
        }
        output
    }
}

thread_local! {
    static AUDIO_QUEUE: RefCell<Option<AudioQueue>> = const { RefCell::new(None) };
}

pub fn init_sound_system(sdl: &Sdl) {
    let audio = sdl.audio();
    let audio = match audio {
        Ok(audio) => audio,
        Err(audio_err) => {
            println!(
                "Failed to initialize audio subsystem: {:?}. Audio will be disabled.",
                audio_err
            );
            return; // Sounds still load and play silently (see with_audio_queue)
        }
    };

    let desired_spec = sdl2::audio::AudioSpecDesired {
        freq: Some(crate::AUDIO_SAMPLE_FREQUENCY),
        channels: Some(crate::AUDIO_CHANNELS as u8), // stereo
        samples: None,                               // default sample size
    };

    let audio_queue = match audio.open_queue::<f32, Option<&str>>(None, &desired_spec) {
        Ok(audio_queue) => Some(audio_queue),
        Err(err) => {
            println!("Failed to open an audio device: {:?}. Audio will be disabled.", err);
            None
        }
    };

    AUDIO_QUEUE.with_borrow_mut(|global_audio_queue| {
        *global_audio_queue = Some(AudioQueue::new(audio_queue));
    });
}

/// Run `f` with the audio queue. Without a sound system (no audio device, or a headless run of the tests), a silent
/// queue is created: sounds load and keep their state, but are never heard.
fn with_audio_queue<T>(f: impl FnOnce(&mut AudioQueue) -> T) -> T {
    AUDIO_QUEUE.with_borrow_mut(|global_audio_queue| {
        let audio_queue = global_audio_queue.get_or_insert_with(|| AudioQueue::new(None));
        f(audio_queue)
    })
}

/// Return a new channel id that can be used to play audio.
pub fn get_available_channel() -> ChannelId {
    with_audio_queue(|audio_queue| {
        let channel_id = ChannelId(audio_queue.audio_buffers.len());
        audio_queue
            .audio_buffers
            .insert(channel_id, AudioResourceBuffer::default());
        channel_id
    })
}

pub fn get_audio_buffer<F, T>(channel_id: ChannelId, f: F) -> T
where
    F: FnOnce(&mut AudioResourceBuffer) -> T,
{
    with_audio_queue(|audio_queue| {
        let audio_buffer = audio_queue
            .audio_buffers
            .entry(channel_id)
            .or_default();
        f(audio_buffer)
    })
}

/// Samples (interleaved stereo) played in `ms` milliseconds
fn samples_in_ms(ms: f32) -> usize {
    (ms * crate::AUDIO_CHANNELS as f32 * crate::AUDIO_SAMPLE_FREQUENCY as f32 / 1000.0) as usize
}

/// Start playing `data_to_play` on a channel, from its beginning. The volume rises over `fade_in_ms`; a sound that is not
/// looped fades to silence over its last `end_fade_ms`. The fades are applied while the sound plays: the sound itself
/// is kept as it is (a looped sound doesn't fade in again at every repetition).
pub fn set_sound_data_to_channel(
    channel_id: ChannelId,
    data_to_play: &[f32],
    fade_in_ms: f32,
    end_fade_ms: f32,
    looped: bool,
) {
    get_audio_buffer(channel_id, |audio_buffer| {
        audio_buffer.clear();
        audio_buffer.buffer.extend(data_to_play.iter().copied());
        audio_buffer.is_looped = looped;
        audio_buffer.progress = 0;
        audio_buffer.fade_in = Fade::new(samples_in_ms(fade_in_ms));
        audio_buffer.end_fade = samples_in_ms(end_fade_ms).min(data_to_play.len() / 4);
        audio_buffer.is_playing = true;
    });
}

/// Add `data_to_play` after what the channel already plays.
pub fn add_sound_data_to_channel(channel_id: ChannelId, data_to_play: &[f32], looped: bool) {
    get_audio_buffer(channel_id, |audio_buffer| {
        audio_buffer.buffer.extend(data_to_play.iter().copied());
        audio_buffer.is_looped = looped;
    });
}

/// Play again a paused sound from where it was, its volume rising over `fade_in_ms`.
pub fn resume_audio(channel_id: ChannelId, fade_in_ms: f32) {
    get_audio_buffer(channel_id, |audio_buffer| {
        audio_buffer.is_playing = true;
        audio_buffer.fade_out = None;
        audio_buffer.fade_in = Fade::new(samples_in_ms(fade_in_ms));
    });
}

/// Pause a sound, its volume going down to silence over `fade_out_ms` first (0: at once).
pub fn pause_audio(channel_id: ChannelId, fade_out_ms: f32) {
    get_audio_buffer(channel_id, |audio_buffer| {
        let samples = samples_in_ms(fade_out_ms);
        if samples == 0 || !audio_buffer.is_playing {
            audio_buffer.is_playing = false;
            audio_buffer.fade_out = None;
        } else {
            audio_buffer.fade_out = Fade::new(samples);
        }
    });
}

pub fn set_volume(channel_id: ChannelId, volume: f32) {
    get_audio_buffer(channel_id, |audio_buffer| {
        audio_buffer.volume = volume;
    });
}

pub fn get_volume(channel_id: ChannelId) -> f32 {
    get_audio_buffer(channel_id, |audio_buffer| audio_buffer.volume)
}

pub fn is_playing(channel_id: ChannelId) -> bool {
    get_audio_buffer(channel_id, |audio_buffer| audio_buffer.is_playing)
}

pub fn flush_all_samples() {
    AUDIO_QUEUE.with_borrow_mut(|global_audio_queue| {
        let Some(global_audio_queue) = global_audio_queue else {
            return;
        };
        if let Some(audio_queue) = &global_audio_queue.audio_queue {
            audio_queue.clear();
        }
        global_audio_queue.audio_buffers.clear();
    });
}

/// You need to call this regularly for the sound system to work: at least once every DURATION_OF_BUFFER_IN_MS
/// (every frame).
pub fn update_sound_system() {
    let desired_samples = samples_in_ms(DURATION_OF_BUFFER_IN_MS);

    AUDIO_QUEUE.with_borrow_mut(|global_audio_queue| {
        let Some(global_audio_queue) = global_audio_queue else {
            return;
        };
        let Some(device) = &global_audio_queue.audio_queue else {
            return; // No device: nothing is heard, and nothing plays on
        };
        // The device counts what it still has to play in bytes, our samples are f32
        let queued_samples = device.size() as usize / size_of::<f32>();
        let samples_to_append = desired_samples.saturating_sub(queued_samples);
        if samples_to_append > 0 {
            let samples = global_audio_queue.mix_audio(samples_to_append);
            let Some(device) = &global_audio_queue.audio_queue else {
                return;
            };
            if let Err(result) = device.queue_audio(&samples) {
                println!("Failed to queue audio: {:?}", result);
            }
            // Resume all the time, we manage the bytes ourselves.
            device.resume();
        }
    });
}
