use vectarine_plugin_sdk::mlua::{
    AnyUserData, Error, FromLua, IntoLua, Lua, Result, UserData, UserDataFields, UserDataMethods,
    Value,
};

use crate::math::Vect;

/// A vector that Lua code can read but not modify, like `vec.ZERO2` or `vec4.RED`.
#[derive(Clone, Copy, Debug)]
pub struct Const<T>(pub T);

pub trait AsVect<const N: usize> {
    fn vect(&self) -> Vect<N>;
}

impl<const N: usize> AsVect<N> for Vect<N> {
    #[inline(always)]
    fn vect(&self) -> Vect<N> {
        *self
    }
}

impl<const N: usize> AsVect<N> for Const<Vect<N>> {
    #[inline(always)]
    fn vect(&self) -> Vect<N> {
        self.0
    }
}

impl<const N: usize> Vect<N> {
    /// Reads a mutable or constant vector.
    pub fn from_userdata(ud: &AnyUserData) -> Result<Self> {
        match ud.borrow::<Self>() {
            Ok(vec) => Ok(*vec),
            Err(Error::UserDataTypeMismatch) => Ok(ud.borrow::<Const<Self>>()?.0),
            Err(err) => Err(err),
        }
    }
}

impl<const N: usize> FromLua for Vect<N> {
    fn from_lua(value: Value, _: &Lua) -> Result<Self> {
        match &value {
            Value::UserData(ud) => Self::from_userdata(ud),
            _ => Err(Error::FromLuaConversionError {
                from: value.type_name(),
                to: format!("Vec{N}"),
                message: Some(format!("expected Vec{N} userdata")),
            }),
        }
    }
}

fn constant_error() -> Error {
    Error::RuntimeError("Constant vectors cannot be modified. Create a copy instead.".to_string())
}

pub fn add_constant_setters<T, F: UserDataFields<T>>(fields: &mut F, names: &[&'static str]) {
    for name in names {
        fields.add_field_method_set(*name, |_, _, _: Value| Err::<(), _>(constant_error()));
    }
}

pub fn add_constant_methods<T, M: UserDataMethods<T>>(methods: &mut M, names: &[&'static str]) {
    for name in names {
        methods.add_method(*name, |_, _, _: Value| Err::<(), _>(constant_error()));
    }
}

/// A vector owned by Lua that Rust objects hold a reference to, so that changing the vector from Lua changes the object.
/// Assigning a vector to such a field stores the vector itself, like assigning a table.
/// Assigning a constant stores a copy, so that the constant stays constant.
#[derive(Clone, Debug)]
pub struct SharedVect<const N: usize>(AnyUserData);

impl<const N: usize> SharedVect<N>
where
    Vect<N>: UserData,
{
    pub fn new(lua: &Lua, value: Vect<N>) -> Result<Self> {
        Ok(Self(lua.create_userdata(value)?))
    }

    pub fn get(&self) -> Result<Vect<N>> {
        Ok(*self.0.borrow::<Vect<N>>()?)
    }

    pub fn set(&self, value: Vect<N>) -> Result<()> {
        *self.0.borrow_mut::<Vect<N>>()? = value;
        Ok(())
    }
}

impl<const N: usize> FromLua for SharedVect<N>
where
    Vect<N>: UserData,
{
    fn from_lua(value: Value, lua: &Lua) -> Result<Self> {
        match value {
            Value::UserData(ud) if ud.is::<Vect<N>>() => Ok(Self(ud)),
            Value::UserData(ud) if ud.is::<Const<Vect<N>>>() => {
                Self::new(lua, ud.borrow::<Const<Vect<N>>>()?.0)
            }
            _ => Err(Error::FromLuaConversionError {
                from: value.type_name(),
                to: format!("Vec{N}"),
                message: Some(format!("expected Vec{N} userdata")),
            }),
        }
    }
}

impl<const N: usize> IntoLua for SharedVect<N> {
    fn into_lua(self, _: &Lua) -> Result<Value> {
        Ok(Value::UserData(self.0))
    }
}

#[cfg(test)]
mod tests {
    use vectarine_plugin_sdk::mlua::{Lua, Result};

    #[test]
    fn constants_cannot_be_modified() -> Result<()> {
        let lua = Lua::new();
        lua.globals()
            .set("vec", crate::lua_env::lua_vec2::setup_vec_api(&lua)?)?;
        lua.globals()
            .set("vec4", crate::lua_env::lua_vec4::setup_vec_api(&lua)?)?;
        lua.load(
            r#"
            local function rejected(f)
                local ok, err = pcall(f)
                return not ok and string.find(tostring(err), "Constant vectors") ~= nil
            end
            assert(rejected(function() vec.ZERO2.x = 1 end))
            assert(rejected(function() vec.ZERO2:add(vec.V2(1, 1)) end))
            assert(rejected(function() vec4.RED.r = 0 end))
            assert(vec.ZERO2.x == 0 and vec4.RED.r == 1 and vec4.RED.g == 0)

            assert((vec.ZERO2 + vec.V2(1, 2)).y == 2)
            assert((vec.V2(1, 2) - vec.ZERO2).x == 1)
            assert(vec4.RED:lerp(vec4.BLUE, 0.5).b == 0.5)
            assert(tostring(vec.ZERO2) == "V2(0, 0)")
            "#,
        )
        .exec()
    }
}
