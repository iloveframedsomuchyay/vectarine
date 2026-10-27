use noise::{NoiseFn, Simplex, Worley};

use crate::{
    lua_env::lua_vect::{AsVect, Const, add_constant_setters},
    math::Vect,
};

pub type Vec4 = Vect<4>;

impl Vec4 {
    #[inline(always)]
    pub const fn new(x: f32, y: f32, z: f32, w: f32) -> Self {
        Self([x, y, z, w])
    }
    #[inline(always)]
    pub fn x(&self) -> f32 {
        self.0[0]
    }
    #[inline(always)]
    pub fn y(&self) -> f32 {
        self.0[1]
    }
    #[inline(always)]
    pub fn z(&self) -> f32 {
        self.0[2]
    }
    #[inline(always)]
    pub fn w(&self) -> f32 {
        self.0[3]
    }
    #[inline]
    pub fn with_x(self, x: f32) -> Self {
        Self([x, self.0[1], self.0[2], self.0[3]])
    }
    #[inline]
    pub fn with_y(self, y: f32) -> Self {
        Self([self.0[0], y, self.0[2], self.0[3]])
    }
    #[inline]
    pub fn with_z(self, z: f32) -> Self {
        Self([self.0[0], self.0[1], z, self.0[3]])
    }
    #[inline]
    pub fn with_w(self, w: f32) -> Self {
        Self([self.0[0], self.0[1], self.0[2], w])
    }
    #[inline]
    pub fn scale(self, k: f32) -> Self {
        self * k
    }
    #[inline]
    pub fn qmul(self, other: Self) -> Self {
        // Quaternion multiplication
        Self::new(
            self.0[0] * other.0[0]
                - self.0[1] * other.0[1]
                - self.0[2] * other.0[2]
                - self.0[3] * other.0[3],
            self.0[0] * other.0[1] + self.0[1] * other.0[0] + self.0[2] * other.0[3]
                - self.0[3] * other.0[2],
            self.0[0] * other.0[2] - self.0[1] * other.0[3]
                + self.0[2] * other.0[0]
                + self.0[3] * other.0[1],
            self.0[0] * other.0[3] + self.0[1] * other.0[2] - self.0[2] * other.0[1]
                + self.0[3] * other.0[0],
        )
    }
    pub fn from_rotation(axis: Self, angle: f32) -> Self {
        let (sin, cos) = (angle / 2.0).sin_cos();
        Self::new(cos, axis.0[0] * sin, axis.0[1] * sin, axis.0[2] * sin)
    }
}

/// The color names are aliases: `r` is `x`, `g` is `y`, etc.
const FIELDS: [[&str; 2]; 4] = [["x", "r"], ["y", "g"], ["z", "b"], ["w", "a"]];

fn add_vec4_fields<T: AsVect<4>, F: vectarine_plugin_sdk::mlua::UserDataFields<T>>(fields: &mut F) {
    for (index, names) in FIELDS.into_iter().enumerate() {
        for name in names {
            fields.add_field_method_get(name, move |_, v| Ok(v.vect().0[index]));
        }
    }
}

fn add_vec4_methods<T: AsVect<4>, M: vectarine_plugin_sdk::mlua::UserDataMethods<T>>(
    methods: &mut M,
) {
    methods.add_method("length", |_, vec, ()| Ok(vec.vect().length()));
    methods.add_method("lengthSq", |_, vec, ()| Ok(vec.vect().length_sq()));
    methods.add_method("distance", |_, vec, (other,): (Vec4,)| {
        Ok((vec.vect() - other).length())
    });
    methods.add_method("scale", |_, vec, (k,): (f32,)| Ok(vec.vect() * k));
    methods.add_method("qmul", |_, vec, (other,): (Vec4,)| {
        Ok(vec.vect().qmul(other))
    });
    methods.add_method("dot", |_, vec, (other,): (Vec4,)| {
        Ok(vec.vect().dot(&other))
    });
    methods.add_method("normalized", |_, vec, ()| Ok(vec.vect().normalized()));
    methods.add_method("round", |_, vec, (digits_of_precision,): (Option<u32>,)| {
        Ok(vec.vect().round(digits_of_precision))
    });
    methods.add_method("abs", |_, vec, ()| Ok(vec.vect().abs()));
    methods.add_method("floor", |_, vec, ()| Ok(vec.vect().floor()));
    methods.add_method("ceil", |_, vec, ()| Ok(vec.vect().ceil()));
    methods.add_method("max", |_, vec, (other,): (Vec4,)| Ok(vec.vect().max(other)));
    methods.add_method("min", |_, vec, (other,): (Vec4,)| Ok(vec.vect().min(other)));
    methods.add_method("lerp", |_, vec, (other, k): (Vec4, f32)| {
        Ok(vec.vect().lerp(other, k))
    });

    let simplex = Simplex::new(noise::Simplex::DEFAULT_SEED);
    let worley = Worley::new(noise::Worley::DEFAULT_SEED);
    methods.add_method("noise", move |_, vec, ()| {
        Ok(simplex.get(vec.vect().0.map(|component| component as f64)))
    });
    methods.add_method("worleyNoise", move |_, vec, ()| {
        Ok(worley.get(vec.vect().0.map(|component| component as f64)))
    });

    methods.add_method("sign", |_, vec, ()| Ok(vec.vect().sign()));
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Add,
        |_, (vec, other): (Vec4, Vec4)| Ok(vec + other),
    );
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Sub,
        |_, (vec, other): (Vec4, Vec4)| Ok(vec - other),
    );
    methods.add_meta_method(
        vectarine_plugin_sdk::mlua::MetaMethod::Unm,
        #[inline(always)]
        |_, vec, ()| Ok(Vect(vec.vect().0.map(|component| -component))),
    );
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Mul,
        |_, (vec, other): (Vec4, Vec4)| Ok(vec * other),
    );
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Div,
        #[inline(always)]
        |_, (vec, other): (Vec4, Vec4)| Ok(vec / other),
    );
    methods.add_meta_method(
        vectarine_plugin_sdk::mlua::MetaMethod::ToString,
        |_, vec, _any: vectarine_plugin_sdk::mlua::Value| {
            let vec = vec.vect();
            Ok(format!(
                "V4({}, {}, {}, {})",
                vec.0[0], vec.0[1], vec.0[2], vec.0[3]
            ))
        },
    );
}

impl vectarine_plugin_sdk::mlua::UserData for Vec4 {
    fn add_fields<F: vectarine_plugin_sdk::mlua::UserDataFields<Self>>(fields: &mut F) {
        add_vec4_fields(fields);
        for (index, names) in FIELDS.into_iter().enumerate() {
            for name in names {
                fields.add_field_method_set(name, move |_, vec, v| {
                    vec.0[index] = v;
                    Ok(())
                });
            }
        }
    }
    fn add_methods<M: vectarine_plugin_sdk::mlua::UserDataMethods<Self>>(methods: &mut M) {
        add_vec4_methods(methods);
    }
}

impl vectarine_plugin_sdk::mlua::UserData for Const<Vec4> {
    fn add_fields<F: vectarine_plugin_sdk::mlua::UserDataFields<Self>>(fields: &mut F) {
        add_vec4_fields(fields);
        add_constant_setters(fields, FIELDS.as_flattened());
    }
    fn add_methods<M: vectarine_plugin_sdk::mlua::UserDataMethods<Self>>(methods: &mut M) {
        add_vec4_methods(methods);
    }
}

pub const BLACK: Vec4 = Vec4::new(0.0, 0.0, 0.0, 1.0);
pub const WHITE: Vec4 = Vec4::new(1.0, 1.0, 1.0, 1.0);
const TRANSPARENT: Vec4 = Vec4::new(0.0, 0.0, 0.0, 0.0);

const RED: Vec4 = Vec4::new(1.0, 0.0, 0.0, 1.0);
const GREEN: Vec4 = Vec4::new(0.0, 1.0, 0.0, 1.0);
const BLUE: Vec4 = Vec4::new(0.0, 0.0, 1.0, 1.0);
const YELLOW: Vec4 = Vec4::new(1.0, 1.0, 0.0, 1.0);
const MAGENTA: Vec4 = Vec4::new(1.0, 0.0, 1.0, 1.0);
const CYAN: Vec4 = Vec4::new(0.0, 1.0, 1.0, 1.0);
const AZURE: Vec4 = Vec4::new(0.0, 0.5, 1.0, 1.0);
const ORANGE: Vec4 = Vec4::new(1.0, 0.5, 0.0, 1.0);
const PURPLE: Vec4 = Vec4::new(0.5, 0.0, 0.5, 1.0);
const SPRING: Vec4 = Vec4::new(0.0, 1.0, 0.5, 1.0);
const LIME: Vec4 = Vec4::new(0.5, 1.0, 0.0, 1.0);
const PINK: Vec4 = Vec4::new(1.0, 0.0, 1.0, 1.0);
const LIGHT_GRAY: Vec4 = Vec4::new(0.7, 0.7, 0.7, 1.0);
const DARK_GRAY: Vec4 = Vec4::new(0.3, 0.3, 0.3, 1.0);
const GRAY: Vec4 = Vec4::new(0.5, 0.5, 0.5, 1.0);
const DARK_RED: Vec4 = Vec4::new(0.5, 0.0, 0.0, 1.0);
const DARK_GREEN: Vec4 = Vec4::new(0.0, 0.5, 0.0, 1.0);
const DARK_BLUE: Vec4 = Vec4::new(0.0, 0.0, 0.5, 1.0);

pub fn setup_vec_api(
    lua: &vectarine_plugin_sdk::mlua::Lua,
) -> vectarine_plugin_sdk::mlua::Result<vectarine_plugin_sdk::mlua::Table> {
    let vec4_module = lua.create_table()?;
    vec4_module.set(
        "V4",
        lua.create_function(|_lua, (x, y, z, w): (f32, f32, f32, f32)| Ok(Vec4::new(x, y, z, w)))?,
    )?;
    vec4_module.set(
        "createColor",
        lua.create_function(|_lua, (r, g, b, a): (f32, f32, f32, f32)| Ok(Vec4::new(r, g, b, a)))?,
    )?;

    vec4_module.set(
        "fromRotation",
        lua.create_function(|_lua, (axis, angle): (Vec4, f32)| {
            Ok(Vec4::from_rotation(axis, angle))
        })?,
    )?;

    vec4_module.set("ZERO4", Const(Vec4::zero()))?;

    // Default colors
    vec4_module.set("BLACK", Const(BLACK))?;
    vec4_module.set("WHITE", Const(WHITE))?;
    vec4_module.set("TRANSPARENT", Const(TRANSPARENT))?;

    vec4_module.set("RED", Const(RED))?;
    vec4_module.set("GREEN", Const(GREEN))?;
    vec4_module.set("BLUE", Const(BLUE))?;

    vec4_module.set("YELLOW", Const(YELLOW))?;
    vec4_module.set("MAGENTA", Const(MAGENTA))?;
    vec4_module.set("CYAN", Const(CYAN))?;

    vec4_module.set("AZURE", Const(AZURE))?;
    vec4_module.set("ORANGE", Const(ORANGE))?;
    vec4_module.set("PURPLE", Const(PURPLE))?;
    vec4_module.set("SPRING", Const(SPRING))?;
    vec4_module.set("LIME", Const(LIME))?;
    vec4_module.set("PINK", Const(PINK))?;

    vec4_module.set("LIGHT_GRAY", Const(LIGHT_GRAY))?;
    vec4_module.set("DARK_GRAY", Const(DARK_GRAY))?;

    vec4_module.set("GRAY", Const(GRAY))?;
    vec4_module.set("DARK_RED", Const(DARK_RED))?;
    vec4_module.set("DARK_GREEN", Const(DARK_GREEN))?;
    vec4_module.set("DARK_BLUE", Const(DARK_BLUE))?;

    Ok(vec4_module)
}
