use std::{cell::RefCell, rc::Rc};

use vectarine_plugin_sdk::mlua::{UserDataFields, UserDataMethods};

use crate::{
    io::IoEnvState,
    lua_env::lua_fastlist::FastList,
    lua_env::lua_vec2::{SharedVec2, Vec2},
};

#[derive(Clone, Debug)]
pub struct Camera2 {
    pub position: SharedVec2,
    pub rotation: f32,
    pub zoom: f32,
}

impl vectarine_plugin_sdk::mlua::IntoLua for Camera2 {
    fn into_lua(
        self,
        lua: &vectarine_plugin_sdk::mlua::Lua,
    ) -> vectarine_plugin_sdk::mlua::Result<vectarine_plugin_sdk::mlua::Value> {
        lua.create_any_userdata(self)
            .map(vectarine_plugin_sdk::mlua::Value::UserData)
    }
}

impl vectarine_plugin_sdk::mlua::FromLua for Camera2 {
    fn from_lua(
        value: vectarine_plugin_sdk::mlua::Value,
        _: &vectarine_plugin_sdk::mlua::Lua,
    ) -> vectarine_plugin_sdk::mlua::Result<Self> {
        match value {
            vectarine_plugin_sdk::mlua::Value::UserData(ud) => Ok(ud.take::<Self>()?),
            _ => Err(vectarine_plugin_sdk::mlua::Error::FromLuaConversionError {
                from: value.type_name(),
                to: "Camera2".to_string(),
                message: Some("Expected Camera2 userdata".to_string()),
            }),
        }
    }
}

impl Camera2 {
    pub fn new(lua: &vectarine_plugin_sdk::mlua::Lua) -> vectarine_plugin_sdk::mlua::Result<Self> {
        Ok(Self {
            position: SharedVec2::new(lua, Vec2::zero())?,
            rotation: 0.0,
            zoom: 1.0,
        })
    }

    /// Transform a world position to screen position (OpenGL coordinates)
    /// This preserves aspect ratio: a square in world space remains square on screen (in pixels).
    /// Centers (0,0) in world to (0,0) in screen.
    pub fn world_to_screen(
        &self,
        point: Vec2,
        window_size: Vec2,
    ) -> vectarine_plugin_sdk::mlua::Result<Vec2> {
        let aspect = window_size.x() / window_size.y();

        let relative = point - self.position.get()?;
        let rotated = relative.rotated(-self.rotation);
        let zoomed = rotated * self.zoom;

        Ok(Vec2::new(zoomed.x(), zoomed.y() * aspect))
    }

    /// Transform a screen position (OpenGL coordinates) to world position
    pub fn screen_to_world(
        &self,
        point: Vec2,
        window_size: Vec2,
    ) -> vectarine_plugin_sdk::mlua::Result<Vec2> {
        let aspect = window_size.x() / window_size.y();

        let unscaled = point.with_y(point.y() / aspect);
        let unzoomed = unscaled / self.zoom;
        let unrotated = unzoomed.rotated(self.rotation);

        Ok(unrotated + self.position.get()?)
    }

    /// Check if a point is visible on the screen
    pub fn is_visible(
        &self,
        point: Vec2,
        window_size: Vec2,
    ) -> vectarine_plugin_sdk::mlua::Result<bool> {
        let p = self.world_to_screen(point, window_size)?;
        Ok(p.x().abs() <= 1.0 && p.y().abs() <= 1.0)
    }
}

pub fn setup_camera_api(
    lua: &vectarine_plugin_sdk::mlua::Lua,
    env_state: &Rc<RefCell<IoEnvState>>,
) -> vectarine_plugin_sdk::mlua::Result<vectarine_plugin_sdk::mlua::Table> {
    lua.register_userdata_type::<Camera2>(|registry| {
        registry.add_field_method_get("position", |_, camera| Ok(camera.position.clone()));
        registry.add_field_method_set("position", |_, camera, position: SharedVec2| {
            camera.position = position;
            Ok(())
        });

        registry.add_field_method_get("rotation", |_, camera| Ok(camera.rotation));
        registry.add_field_method_set("rotation", |_, camera, rotation: f32| {
            camera.rotation = rotation;
            Ok(())
        });

        registry.add_field_method_get("zoom", |_, camera| Ok(camera.zoom));
        registry.add_field_method_set("zoom", |_, camera, zoom: f32| {
            camera.zoom = zoom;
            Ok(())
        });

        registry.add_method("screen", {
            let env_state = env_state.clone();
            move |_, camera, point: Vec2| {
                let state = env_state.borrow();
                let window_size = Vec2::new(
                    state.window_width as f32 / state.px_ratio_x,
                    state.window_height as f32 / state.px_ratio_y,
                );
                camera.world_to_screen(point, window_size)
            }
        });

        registry.add_method("world", {
            let env_state = env_state.clone();
            move |_, camera, point: Vec2| {
                let state = env_state.borrow();
                let window_size = Vec2::new(
                    state.window_width as f32 / state.px_ratio_x,
                    state.window_height as f32 / state.px_ratio_y,
                );
                camera.screen_to_world(point, window_size)
            }
        });

        registry.add_method("isVisible", {
            let env_state = env_state.clone();
            move |_, camera, point: Vec2| {
                let state = env_state.borrow();
                let window_size = Vec2::new(
                    state.window_width as f32 / state.px_ratio_x,
                    state.window_height as f32 / state.px_ratio_y,
                );
                camera.is_visible(point, window_size)
            }
        });

        registry.add_method("screenFastlist", {
            let env_state = env_state.clone();
            move |_, camera, points: FastList| {
                let state = env_state.borrow();
                let window_size = Vec2::new(
                    state.window_width as f32 / state.px_ratio_x,
                    state.window_height as f32 / state.px_ratio_y,
                );
                let aspect = window_size.x() / window_size.y();
                let zoom = camera.zoom;
                let rot_vec = Vec2::from_angle(-camera.rotation);
                let pos = camera.position.get()?;

                let data = points
                    .data
                    .iter()
                    .map(|p| {
                        let rel = *p - pos;
                        let rotated = rel.cmul(rot_vec);
                        let zoomed = rotated * zoom;
                        Vec2::new(zoomed.x(), zoomed.y() * aspect)
                    })
                    .collect();

                Ok(FastList::from_vec(data))
            }
        });

        registry.add_method("worldFastlist", {
            let env_state = env_state.clone();
            move |_, camera, points: FastList| {
                let state = env_state.borrow();
                let window_size = Vec2::new(
                    state.window_width as f32 / state.px_ratio_x,
                    state.window_height as f32 / state.px_ratio_y,
                );
                let aspect = window_size.x() / window_size.y();
                let zoom = camera.zoom;
                let rot_vec = Vec2::from_angle(camera.rotation);
                let pos = camera.position.get()?;

                let data = points
                    .data
                    .iter()
                    .map(|p| {
                        let unscaled = p.with_y(p.y() / aspect);
                        let unzoomed = unscaled / zoom;
                        let unrotated = unzoomed.cmul(rot_vec);
                        unrotated + pos
                    })
                    .collect();

                Ok(FastList::from_vec(data))
            }
        });

        registry.add_method_mut("moveTowards", |_, camera, (point, amount): (Vec2, f32)| {
            let position = camera.position.get()?;
            camera.position.set(position + (point - position) * amount)
        });

        registry.add_method_mut("rotateTowards", |_, camera, (angle, amount): (f32, f32)| {
            camera.rotation = camera.rotation + (angle - camera.rotation) * amount;
            Ok(())
        });

        registry.add_method_mut("zoomTowards", |_, camera, (zoom, amount): (f32, f32)| {
            camera.zoom = camera.zoom + (zoom - camera.zoom) * amount;
            Ok(())
        });
    })?;

    let camera_module = lua.create_table()?;

    camera_module.set("new", lua.create_function(|lua, ()| Camera2::new(lua))?)?;

    Ok(camera_module)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn world_to_screen() -> vectarine_plugin_sdk::mlua::Result<()> {
        let lua = vectarine_plugin_sdk::mlua::Lua::new();
        let camera = Camera2::new(&lua)?;
        let win = Vec2::new(800.0, 600.0);
        let aspect = 800.0 / 600.0;
        let p0 = Vec2::new(0.0, 0.0);
        let s0 = camera.world_to_screen(p0, win)?;
        assert!((s0.x() - 0.0).abs() < 1e-6);
        assert!((s0.y() - 0.0).abs() < 1e-6);

        // Aspect ratio preserved: (1,1) maps to (1, aspect)
        let p1 = Vec2::new(1.0, 1.0);
        let s1 = camera.world_to_screen(p1, win)?;
        assert!((s1.x() - 1.0).abs() < 1e-6);
        assert!((s1.y() - aspect).abs() < 1e-6);
        Ok(())
    }

    #[test]
    fn zoom_scaling() -> vectarine_plugin_sdk::mlua::Result<()> {
        let lua = vectarine_plugin_sdk::mlua::Lua::new();
        let mut camera = Camera2::new(&lua)?;
        camera.zoom = 2.0;
        let win = Vec2::new(100.0, 100.0); // Aspect 1.0
        let p = Vec2::new(1.0, 0.0);
        let s = camera.world_to_screen(p, win)?;
        assert!((s.x() - 2.0).abs() < 1e-6);
        assert!((s.y() - 0.0).abs() < 1e-6);
        Ok(())
    }

    #[test]
    fn round_trip() -> vectarine_plugin_sdk::mlua::Result<()> {
        let lua = vectarine_plugin_sdk::mlua::Lua::new();
        let mut camera = Camera2::new(&lua)?;
        camera.position.set(Vec2::new(10.0, -5.0))?;
        camera.rotation = 1.5;
        camera.zoom = 0.5;

        let win = Vec2::new(800.0, 600.0);
        let p = Vec2::new(123.0, 456.0);

        let s = camera.world_to_screen(p, win)?;
        let p2 = camera.screen_to_world(s, win)?;

        assert!((p.x() - p2.x()).abs() < 1e-5);
        assert!((p.y() - p2.y()).abs() < 1e-5);
        Ok(())
    }

    fn lua_with_camera() -> vectarine_plugin_sdk::mlua::Result<vectarine_plugin_sdk::mlua::Lua> {
        let lua = vectarine_plugin_sdk::mlua::Lua::new();
        lua.set_compiler(
            vectarine_plugin_sdk::mlua::chunk::Compiler::new()
                .set_optimization_level(2)
                .set_type_info_level(1),
        );
        let env_state = Rc::new(RefCell::new(IoEnvState::default()));
        let globals = lua.globals();
        globals.set("vec", crate::lua_env::lua_vec2::setup_vec_api(&lua)?)?;
        globals.set("camera", setup_camera_api(&lua, &env_state)?)?;
        Ok(lua)
    }

    #[test]
    fn position_is_shared() -> vectarine_plugin_sdk::mlua::Result<()> {
        lua_with_camera()?
            .load(
                r#"
                local c = camera.new()
                c.position.x = 3
                assert(c.position.x == 3)

                local a = vec.V2(1, 1)
                c.position = a
                a.x = 2
                assert(c.position.x == 2)

                local p = c.position
                p.y = 5
                assert(a.y == 5)
                c:moveTowards(vec.V2(4, 5), 0.5)
                assert(p.x == 3)

                c.position = vec.ZERO2
                c.position.x = 1
                assert(vec.ZERO2.x == 0)
                "#,
            )
            .exec()
    }

    // cargo test --release -p runtime camera_benchmark -- --ignored --nocapture
    #[test]
    #[ignore]
    fn camera_benchmark() -> vectarine_plugin_sdk::mlua::Result<()> {
        let lua = lua_with_camera()?;

        let iterations = 1_000_000;
        for (name, code) in [
            (
                "a + b",
                "local a, b = vec.V2(1, 2), vec.V2(3, 4) for i = 1, N do a = a + b end",
            ),
            (
                "cam.position",
                "local c = camera.new() for i = 1, N do local p = c.position end",
            ),
            (
                "cam.position.x = i",
                "local c = camera.new() for i = 1, N do c.position.x = i end",
            ),
            (
                "cam:screen(p)",
                "local c = camera.new() local p = vec.V2(1, 2) for i = 1, N do c:screen(p) end",
            ),
        ] {
            let function: vectarine_plugin_sdk::mlua::Function =
                lua.load(format!("return function(N) {code} end")).eval()?;
            let start = std::time::Instant::now();
            function.call::<()>(iterations)?;
            let per_call = start.elapsed().as_secs_f64() * 1e9 / iterations as f64;
            println!("{name:<20} {per_call:6.1} ns");
        }
        Ok(())
    }
}
