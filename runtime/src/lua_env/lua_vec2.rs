use noise::{NoiseFn, Simplex, Worley};

use crate::{
    lua_env::lua_vect::{AsVect, Const, SharedVect, add_constant_methods, add_constant_setters},
    math::Vect,
};

pub type Vec2 = Vect<2>;
pub type SharedVec2 = SharedVect<2>;

impl Vec2 {
    #[inline(always)]
    pub const fn new(x: f32, y: f32) -> Self {
        Self([x, y])
    }
    #[inline(always)]
    pub const fn x(&self) -> f32 {
        self.0[0]
    }
    #[inline(always)]
    pub const fn y(&self) -> f32 {
        self.0[1]
    }
    #[inline]
    pub const fn with_x(self, x: f32) -> Self {
        Self([x, self.0[1]])
    }
    #[inline]
    pub const fn with_y(self, y: f32) -> Self {
        Self([self.0[0], y])
    }
    #[inline]
    pub fn scale(self, k: f32) -> Self {
        self * k
    }
    #[inline]
    pub fn cmul(self, other: Self) -> Self {
        Self::new(
            self.0[0] * other.0[0] - self.0[1] * other.0[1],
            self.0[1] * other.0[0] + self.0[0] * other.0[1],
        )
    }
    #[inline]
    pub fn rotated(self, angle_rad: f32) -> Self {
        let cos_a = angle_rad.cos();
        let sin_a = angle_rad.sin();
        self.cmul(Self::new(cos_a, sin_a))
    }
    #[inline]
    pub fn cross(self, other: Self) -> f32 {
        self.0[0] * other.0[1] - self.0[1] * other.0[0]
    }
    #[inline]
    pub fn angle(self) -> f32 {
        self.0[1].atan2(self.0[0])
    }
    #[inline]
    pub fn from_angle(angle_rad: f32) -> Self {
        Self::new(angle_rad.cos(), angle_rad.sin())
    }

    #[inline]
    pub fn to_polar(self) -> Self {
        Self::new(self.length(), self.angle())
    }
    #[inline]
    pub fn to_cartesian(self) -> Self {
        let length = self.x();
        let angle = self.y();
        Self::from_angle(angle) * length
    }
}

const IN_PLACE_METHODS: [&str; 4] = ["add", "sub", "mul", "rescale"];

fn add_vec2_fields<T: AsVect<2>, F: vectarine_plugin_sdk::mlua::UserDataFields<T>>(fields: &mut F) {
    fields.add_field_method_get("x", |_, v| Ok(v.vect().0[0]));
    fields.add_field_method_get("y", |_, v| Ok(v.vect().0[1]));
}

fn add_vec2_methods<T: AsVect<2>, M: vectarine_plugin_sdk::mlua::UserDataMethods<T>>(
    methods: &mut M,
) {
    methods.add_method(
        "length",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().length()),
    );
    methods.add_method(
        "scale",
        #[inline(always)]
        |_, vec, (k,): (f32,)| Ok(vec.vect() * k),
    );
    methods.add_method(
        "cmul",
        #[inline(always)]
        |_, vec, (other,): (Vec2,)| Ok(vec.vect().cmul(other)),
    );
    methods.add_method(
        "dot",
        #[inline(always)]
        |_, vec, (other,): (Vec2,)| Ok(vec.vect().dot(&other)),
    );
    methods.add_method(
        "lengthSq",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().length_sq()),
    );
    methods.add_method(
        "normalized",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().normalized()),
    );
    methods.add_method(
        "abs",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().abs()),
    );
    methods.add_method(
        "round",
        #[inline(always)]
        |_, vec, (digits_of_precision,): (Option<u32>,)| Ok(vec.vect().round(digits_of_precision)),
    );
    methods.add_method(
        "angle",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().angle()),
    );
    methods.add_method(
        "floor",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().floor()),
    );
    methods.add_method(
        "lerp",
        #[inline(always)]
        |_, vec, (other, k)| Ok(vec.vect().lerp(other, k)),
    );
    methods.add_method(
        "ceil",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().ceil()),
    );
    methods.add_method(
        "max",
        #[inline(always)]
        |_, vec, (other,): (Vec2,)| Ok(vec.vect().max(other)),
    );
    methods.add_method(
        "min",
        #[inline(always)]
        |_, vec, (other,): (Vec2,)| Ok(vec.vect().min(other)),
    );
    methods.add_method(
        "sign",
        #[inline(always)]
        |_, vec, ()| Ok(vec.vect().sign()),
    );
    let simplex = Simplex::new(noise::Simplex::DEFAULT_SEED);
    methods.add_method(
        "noise",
        #[inline(always)]
        move |_, vec, ()| {
            let vec = vec.vect();
            let f64vec = [vec.0[0] as f64, vec.0[1] as f64];
            Ok(simplex.get(f64vec))
        },
    );
    let worley = Worley::new(noise::Worley::DEFAULT_SEED);
    methods.add_method(
        "worleyNoise",
        #[inline(always)]
        move |_, vec, ()| {
            let vec = vec.vect();
            let f64vec = [vec.0[0] as f64, vec.0[1] as f64];
            Ok(worley.get(f64vec))
        },
    );
    methods.add_method(
        "distance",
        #[inline(always)]
        |_, vec, (other,): (Vec2,)| Ok((vec.vect() - other).length()),
    );
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Add,
        #[inline(always)]
        |_, (vec, other): (Vec2, Vec2)| Ok(vec + other),
    );
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Sub,
        #[inline(always)]
        |_, (vec, other): (Vec2, Vec2)| Ok(vec - other),
    );
    methods.add_meta_method(
        vectarine_plugin_sdk::mlua::MetaMethod::Unm,
        #[inline(always)]
        |_, vec, ()| {
            let vec = vec.vect();
            Ok(Vec2::new(-vec.0[0], -vec.0[1]))
        },
    );
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Mul,
        #[inline(always)]
        |_, (vec, other): (Vec2, Vec2)| Ok(vec * other),
    );
    methods.add_meta_function(
        vectarine_plugin_sdk::mlua::MetaMethod::Div,
        #[inline(always)]
        |_, (vec, other): (Vec2, Vec2)| Ok(vec / other),
    );
    methods.add_meta_method(
        vectarine_plugin_sdk::mlua::MetaMethod::ToString,
        #[inline(always)]
        |_, vec, _any: vectarine_plugin_sdk::mlua::Value| {
            let vec = vec.vect();
            Ok(format!("V2({}, {})", vec.0[0], vec.0[1]))
        },
    );
}

/// Returns the vector itself rather than a copy, so that calls can be chained.
fn add_in_place_method<A, M>(methods: &mut M, name: &'static str, f: fn(&mut Vec2, A))
where
    A: vectarine_plugin_sdk::mlua::FromLua + 'static,
    M: vectarine_plugin_sdk::mlua::UserDataMethods<Vec2>,
{
    methods.add_function(
        name,
        #[inline(always)]
        move |_, (vec, arg): (vectarine_plugin_sdk::mlua::AnyUserData, A)| {
            f(&mut *vec.borrow_mut::<Vec2>()?, arg);
            Ok(vec)
        },
    );
}

// We implement intoLua for Vec2 as a shortcut for using SharedVec2 and then getting the Vec2 inside.
// This is useful for functions that just need to read a Vec2 without mutating it or storing it.
impl vectarine_plugin_sdk::mlua::UserData for Vec2 {
    fn add_fields<F: vectarine_plugin_sdk::mlua::UserDataFields<Self>>(fields: &mut F) {
        add_vec2_fields(fields);
        fields.add_field_method_set("x", |_, vec, v| {
            vec.0[0] = v;
            Ok(())
        });
        fields.add_field_method_set("y", |_, vec, v| {
            vec.0[1] = v;
            Ok(())
        });
    }
    fn add_methods<M: vectarine_plugin_sdk::mlua::UserDataMethods<Self>>(methods: &mut M) {
        add_vec2_methods(methods);

        let [add, sub, mul, rescale] = IN_PLACE_METHODS;
        add_in_place_method(methods, add, |vec, other: Vec2| *vec = *vec + other);
        add_in_place_method(methods, sub, |vec, other: Vec2| *vec = *vec - other);
        add_in_place_method(methods, mul, |vec, other: Vec2| *vec = *vec * other);
        add_in_place_method(methods, rescale, |vec, k: f32| *vec = *vec * k);
    }
}

impl vectarine_plugin_sdk::mlua::UserData for Const<Vec2> {
    fn add_fields<F: vectarine_plugin_sdk::mlua::UserDataFields<Self>>(fields: &mut F) {
        add_vec2_fields(fields);
        add_constant_setters(fields, &["x", "y"]);
    }
    fn add_methods<M: vectarine_plugin_sdk::mlua::UserDataMethods<Self>>(methods: &mut M) {
        add_vec2_methods(methods);
        add_constant_methods(methods, &IN_PLACE_METHODS);
    }
}

pub fn setup_vec_api(
    lua: &vectarine_plugin_sdk::mlua::Lua,
) -> vectarine_plugin_sdk::mlua::Result<vectarine_plugin_sdk::mlua::Table> {
    let vec2_module = lua.create_table()?;
    vec2_module.set(
        "V2",
        lua.create_function(|_lua, (x, y): (f32, f32)| Ok(Vec2::new(x, y)))?,
    )?;

    vec2_module.set(
        "fromAngle",
        lua.create_function(|_lua, (angle_rad, length): (f32, Option<f32>)| {
            let v2 = Vec2::from_angle(angle_rad);
            let scaled = v2 * length.unwrap_or(1.0);
            Ok(scaled)
        })?,
    )?;

    vec2_module.set("ZERO2", Const(Vec2::zero()))?;
    Ok(vec2_module)
}

#[cfg(test)]
mod tests {
    use vectarine_plugin_sdk::mlua::{Lua, Result};

    #[test]
    fn in_place_methods_return_the_vector() -> Result<()> {
        let lua = Lua::new();
        lua.globals().set("vec", super::setup_vec_api(&lua)?)?;
        lua.load(
            r#"
            local a = vec.V2(1, 2)
            assert(rawequal(a:add(vec.V2(1, 1)), a))
            assert(rawequal(a:sub(vec.V2(0, 1)):mul(vec.V2(2, 3)):rescale(0.5), a))
            assert(a.x == 2 and a.y == 3)
            a:add(a)
            assert(a.x == 4 and a.y == 6)
            "#,
        )
        .exec()
    }
}
