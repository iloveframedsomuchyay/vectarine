use std::{
    cell::RefCell,
    collections::HashMap,
    rc::{Rc, Weak},
};

use vectarine_plugin_sdk::rapier2d::prelude::{
    CCDSolver, Collider, ColliderBuilder, ColliderSet, DefaultBroadPhase, ImpulseJointHandle,
    ImpulseJointSet, IntegrationParameters, IslandManager, MultibodyJointSet, NarrowPhase,
    PhysicsPipeline, QueryFilter, RevoluteJointBuilder, RigidBody, RigidBodyBuilder,
    RigidBodyHandle, RigidBodySet,
};
use vectarine_plugin_sdk::{
    mlua::{AnyUserData, FromLua, IntoLua, UserDataFields, UserDataMethods, UserDataRef},
    rapier2d,
};

use crate::{
    auto_impl_lua_take,
    game_resource::ResourceManager,
    lua_env::{
        add_fn_to_table, is_valid_data_type,
        lua_camera::Camera2,
        lua_tile::{
            TilemapResourceId,
            tilemap::{GeneratedTilemap, Tilemap},
        },
        lua_vec2::{SharedVec2, Vec2},
    },
};

// MARK: World2

/// Lua wrapper around a rapier physics world
pub struct PhysicsWorld2 {
    physics_pipeline: PhysicsPipeline,
    rigid_body_set: RigidBodySet,
    collider_set: ColliderSet,
    gravity: SharedVec2,
    integration_parameters: IntegrationParameters,
    island_manager: IslandManager,
    broad_phase: DefaultBroadPhase,
    narrow_phase: NarrowPhase,
    impulse_joint_set: ImpulseJointSet,
    multibody_joint_set: MultibodyJointSet,
    ccd_solver: CCDSolver,
    camera: Option<vectarine_plugin_sdk::mlua::Value>,

    extras: HashMap<RigidBodyHandle, ExtraObjectData>,
}

pub fn ensure_camera_is_valid(
    maybe_camera: &vectarine_plugin_sdk::mlua::Value,
) -> vectarine_plugin_sdk::mlua::Result<()> {
    if !is_valid_data_type::<Camera2>(maybe_camera) {
        return Err(vectarine_plugin_sdk::mlua::Error::FromLuaConversionError {
            from: maybe_camera.type_name(),
            to: "Camera2".to_string(),
            message: Some("Invalid camera when creating World2".to_string()),
        });
    }
    Ok(())
}

impl PhysicsWorld2 {
    fn new(
        camera: Option<vectarine_plugin_sdk::mlua::Value>,
        gravity: SharedVec2,
    ) -> vectarine_plugin_sdk::mlua::Result<Self> {
        let camera = if let Some(camera) = camera {
            ensure_camera_is_valid(&camera)?;
            Some(camera)
        } else {
            None
        };

        Ok(Self {
            physics_pipeline: PhysicsPipeline::new(),
            rigid_body_set: RigidBodySet::new(),
            collider_set: ColliderSet::new(),
            gravity,
            integration_parameters: IntegrationParameters::default(),
            island_manager: IslandManager::new(),
            broad_phase: DefaultBroadPhase::new(),
            narrow_phase: NarrowPhase::new(),
            impulse_joint_set: ImpulseJointSet::new(),
            multibody_joint_set: MultibodyJointSet::new(),
            ccd_solver: CCDSolver::new(),
            camera,
            extras: HashMap::new(),
        })
    }

    fn object(&self, handle: RigidBodyHandle) -> Option<AnyUserData> {
        self.extras.get(&handle).map(|extra| extra.object.clone())
    }

    /// Lua can edit positions and speeds in place, without going through a setter.
    fn push_shared_vectors(&mut self) -> vectarine_plugin_sdk::mlua::Result<()> {
        for extra in self.extras.values() {
            let object = extra.object.borrow::<Object2>()?;
            let position = to_rapier(object.position.get()?);
            let speed = to_rapier(object.speed.get()?);
            let Some(rigid_body) = self.rigid_body_set.get(object.rigid_body_handle) else {
                continue;
            };
            let moved = rigid_body.translation() != position;
            let sped_up = rigid_body.linvel() != speed;
            if !moved && !sped_up {
                continue;
            }
            let Some(rigid_body) = self.rigid_body_set.get_mut(object.rigid_body_handle) else {
                continue;
            };
            if moved {
                rigid_body.set_translation(position, true);
            }
            if sped_up {
                rigid_body.set_linvel(speed, true);
            }
        }
        Ok(())
    }

    fn pull_shared_vectors(&self) -> vectarine_plugin_sdk::mlua::Result<()> {
        for extra in self.extras.values() {
            let object = extra.object.borrow::<Object2>()?;
            let Some(rigid_body) = self.rigid_body_set.get(object.rigid_body_handle) else {
                continue;
            };
            object.position.set(from_rapier(rigid_body.translation()))?;
            object.speed.set(from_rapier(rigid_body.linvel()))?;
        }
        Ok(())
    }
}

fn to_rapier(vec: Vec2) -> rapier2d::math::Vec2 {
    rapier2d::math::Vec2::new(vec.x(), vec.y())
}

fn from_rapier(vec: rapier2d::math::Vec2) -> Vec2 {
    Vec2::new(vec.x, vec.y)
}

#[derive(Clone)]
pub struct LuaPhysicsWorld2(Rc<RefCell<PhysicsWorld2>>);
auto_impl_lua_take!(LuaPhysicsWorld2, LuaPhysicsWorld2);

// MARK: Collider2

struct Collider2 {
    collider: Collider,
}
auto_impl_lua_take!(Collider2, Collider2);

// MARK: Joint2

struct Joint2 {
    joint: ImpulseJointHandle,
    world: Weak<RefCell<PhysicsWorld2>>,
}
auto_impl_lua_take!(Joint2, Joint2);

// MARK: Object2

/// Each body has a single Object2, so that its position and speed vectors are shared by everyone holding it.
pub struct Object2 {
    pub rigid_body_handle: RigidBodyHandle,
    pub world: Weak<RefCell<PhysicsWorld2>>,
    position: SharedVec2,
    speed: SharedVec2,
}

impl Object2 {
    pub fn is_out_of_world(&self) -> bool {
        self.world.upgrade().is_none()
    }
    pub fn position(&self) -> Option<Vec2> {
        self.position.get().ok()
    }
    pub fn velocity(&self) -> Option<Vec2> {
        self.speed.get().ok()
    }
    pub fn set_position(&self, position: Vec2) -> Option<()> {
        self.position.set(position).ok()?;
        access_rigid_body_mut(self, |_, rigid_body| {
            rigid_body.set_translation(to_rapier(position), true);
        })
        .ok()
    }
    pub fn set_velocity(&self, velocity: Vec2) -> Option<()> {
        self.speed.set(velocity).ok()?;
        access_rigid_body_mut(self, |_, rigid_body| {
            rigid_body.set_linvel(to_rapier(velocity), true);
        })
        .ok()
    }
}

struct ExtraObjectData {
    object: AnyUserData,
    tags: vectarine_plugin_sdk::mlua::Table,
    extra_custom: vectarine_plugin_sdk::mlua::Value,
}

pub fn setup_physics_api(
    lua: &vectarine_plugin_sdk::mlua::Lua,
    resources: &Rc<ResourceManager>,
) -> vectarine_plugin_sdk::mlua::Result<vectarine_plugin_sdk::mlua::Table> {
    let physics_module = lua.create_table()?;

    // MARK: World2 fn
    add_fn_to_table(lua, &physics_module, "newWorld2", {
        move |lua, (gravity, camera): (Option<SharedVec2>, vectarine_plugin_sdk::mlua::Value)| {
            let camera = if camera.is_nil() { None } else { Some(camera) };
            let gravity = match gravity {
                Some(gravity) => gravity,
                None => SharedVec2::new(lua, Vec2::zero())?,
            };
            let world = PhysicsWorld2::new(camera, gravity)?;
            Ok(LuaPhysicsWorld2(Rc::new(RefCell::new(world))))
        }
    });

    lua.register_userdata_type::<LuaPhysicsWorld2>(|registry| {
        registry.add_field_method_get("camera", |_, world| {
            let cam = world.0.borrow().camera.clone();
            match cam {
                Some(cam) => Ok(cam),
                None => Ok(vectarine_plugin_sdk::mlua::Nil),
            }
        });
        registry.add_field_method_set("camera", |_, world, new_camera: vectarine_plugin_sdk::mlua::Value| {
            if new_camera.is_nil() {
                world.0.borrow_mut().camera = None;
            } else {
                ensure_camera_is_valid(&new_camera)?;
                world.0.borrow_mut().camera = Some(new_camera);
            }
            Ok(())
        });
        registry.add_field_method_get("gravity", |_, world| Ok(world.0.borrow().gravity.clone()));
        registry.add_field_method_set("gravity", |_, world, gravity: SharedVec2| {
            world.0.borrow_mut().gravity = gravity;
            Ok(())
        });

        registry.add_method_mut("step", |_, world, dt: f32| {
            let mut world = world.0.borrow_mut();
            let world = &mut *world;
            let physics_hooks = ();
            let event_handler = ();

            let rapier_gravity = to_rapier(world.gravity.get()?);
            world.integration_parameters.dt = dt;
            world.push_shared_vectors()?;

            world.physics_pipeline.step(
                rapier_gravity,
                &world.integration_parameters,
                &mut world.island_manager,
                &mut world.broad_phase,
                &mut world.narrow_phase,
                &mut world.rigid_body_set,
                &mut world.collider_set,
                &mut world.impulse_joint_set,
                &mut world.multibody_joint_set, // unused, impulse joints are better for our use-case.
                &mut world.ccd_solver,
                &physics_hooks,
                &event_handler,
            );
            world.pull_shared_vectors()
        });

        registry.add_method_mut("createObject", {
            move |lua,
                  lua_world,
                  (position, mass, maybe_collider, tags, body_type): (
                Vec2,
                f32,
                vectarine_plugin_sdk::mlua::AnyUserData,
                vectarine_plugin_sdk::mlua::Table,
                String,
            )| {
                let collider = maybe_collider.borrow::<Collider2>()?;
                let mut world = lua_world.0.borrow_mut();
                let world = &mut *world;

                let body_builder = match body_type.as_str() {
                    "dynamic" => RigidBodyBuilder::dynamic(),
                    "static" => RigidBodyBuilder::fixed(),
                    "kinematic" => RigidBodyBuilder::kinematic_velocity_based(),
                    _ => {
                        return Err(vectarine_plugin_sdk::mlua::Error::FromLuaConversionError {
                            from: "string",
                            to: "RigidBodyType".to_string(),
                            message: Some(
                                "Invalid body type, expected 'dynamic', 'static' or 'kinematic'"
                                    .to_string(),
                            ),
                        });
                    }
                };
                let pose = rapier2d::math::Pose2::translation(position.x(), position.y());
                let body = body_builder
                    .pose(pose)
                    .additional_mass(mass)
                    .build();
                let body_handle = world.rigid_body_set.insert(body);
                let collider = collider.collider.clone();
                world.collider_set.insert_with_parent(
                    collider,
                    body_handle,
                    &mut world.rigid_body_set,
                );

                // The position is copied: objects created from the same vector must not move together.
                let object = lua.create_any_userdata(Object2 {
                    rigid_body_handle: body_handle,
                    world: Rc::downgrade(&lua_world.0),
                    position: SharedVec2::new(lua, position)?,
                    speed: SharedVec2::new(lua, Vec2::zero())?,
                })?;
                world.extras.insert(
                    body_handle,
                    ExtraObjectData {
                        object: object.clone(),
                        tags,
                        extra_custom: vectarine_plugin_sdk::mlua::Nil,
                    },
                );
                Ok(object)
            }
        });

        registry.add_method_mut("removeObject", |_, world, object: UserDataRef<Object2>| {
            let mut world = world.0.borrow_mut();
            let world = &mut *world;
            world.extras.remove(&object.rigid_body_handle);
            world.rigid_body_set.remove(
                object.rigid_body_handle,
                &mut world.island_manager,
                &mut world.collider_set,
                &mut world.impulse_joint_set,
                &mut world.multibody_joint_set,
                true,
            );
            Ok(())
        });

        registry.add_method_mut(
            "getObjects",
            |_, lua_world, tags: Option<Vec<vectarine_plugin_sdk::mlua::Value>>| {
                let tags = tags.unwrap_or_default();
                let mut world = lua_world.0.borrow_mut();
                let world = &mut *world;
                let objects = world
                    .extras
                    .iter()
                    .filter(|(_, extra)| {
                        tags.iter().all(|queried_tag| {
                            extra
                                .tags
                                .pairs::<vectarine_plugin_sdk::mlua::Value, vectarine_plugin_sdk::mlua::Value>()
                                .filter_map(|o| o.ok())
                                .any(|(_, object_tag)| object_tag == *queried_tag)
                        })
                    })
                    .map(|(_, extra)| extra.object.clone())
                    .collect::<Vec<_>>();
                Ok(objects)
            },
        );

        registry.add_method_mut("getObjectsAtPoint", {
            move |_, lua_world, (point,): (Vec2,)| {
                let world = lua_world.0.borrow();
                let world = &*world;
                let filter = QueryFilter::default();
                let query_pipeline = world.broad_phase.as_query_pipeline(
                    world.narrow_phase.query_dispatcher(),
                    &world.rigid_body_set,
                    &world.collider_set,
                    filter,
                );
                let matches =
                    query_pipeline.intersect_point(rapier2d::math::Vec2::new(point.x(), point.y()));
                Ok(matches
                    .filter_map(|m| world.object(m.1.parent()?))
                    .collect::<Vec<_>>())
            }
        });

        registry.add_method_mut("getObjectsInArea", {
            move |_, lua_world, (position, size): (Vec2, Vec2)| {
                use rapier2d::math;
                use rapier2d::parry;

                let world = lua_world.0.borrow();
                let world = &*world;
                let filter = QueryFilter::default();
                let query_pipeline = world.broad_phase.as_query_pipeline(
                    world.narrow_phase.query_dispatcher(),
                    &world.rigid_body_set,
                    &world.collider_set,
                    filter,
                );
                let cuboid_size = math::Vec2::new(size.x() / 2.0, size.y() / 2.0);
                let shape = parry::shape::Cuboid::new(cuboid_size);
                let shape_pos = math::Pose2::translation(
                    position.x() + size.x() / 2.0,
                    position.y() + size.y() / 2.0
                );
                let matches = query_pipeline.intersect_shape(shape_pos, &shape);

                Ok(matches
                    .filter_map(|m| world.object(m.1.parent()?))
                    .collect::<Vec<_>>())
            }
        });

        registry.add_method_mut("getObjectsIntersectingRay", {
            move |lua, lua_world, (position, direction, max_length): (Vec2, Vec2, Option<f32>)| {
                let world = lua_world.0.borrow();
                let world = &*world;
                let filter = QueryFilter::default();
                let query_pipeline = world.broad_phase.as_query_pipeline(
                    world.narrow_phase.query_dispatcher(),
                    &world.rigid_body_set,
                    &world.collider_set,
                    filter,
                );
                let position = rapier2d::math::Vec2::new(position.x(), position.y());
                let direction = rapier2d::math::Vec2::new(direction.x(), direction.y());
                let ray = rapier2d::parry::query::Ray::new(position, direction);
                let matches =
                    query_pipeline.intersect_ray(ray, max_length.unwrap_or(10000.0), true);
                Ok(matches
                    .filter_map(|(_, collider, intersection)| {
                        let o = world.object(collider.parent()?)?;
                        let table = lua.create_table().ok()?;
                        table.raw_set("object", o).ok()?;
                        table
                            .raw_set("timeOfImpact", intersection.time_of_impact)
                            .ok()?;
                        Some(table)
                    })
                    .collect::<Vec<_>>())
            }
        });

        registry.add_method_mut("getJoints", {
            move |_, lua_world, (): ()| {
                let world = lua_world.0.borrow();
                let world = &*world;
                let handles = world
                    .impulse_joint_set
                    .iter()
                    .map(|(joint_handle, _)| Joint2 {
                        joint: joint_handle,
                        world: Rc::downgrade(&lua_world.0),
                    })
                    .collect::<Vec<_>>();
                Ok(handles)
            }
        });

        // MARK: Joint2 fn
        registry.add_method_mut("createDistanceJoint", {
            move |_, lua_world, (object1, object2): (UserDataRef<Object2>, UserDataRef<Object2>)| {
                let mut world = lua_world.0.borrow_mut();
                let world = &mut *world;
                let joint = RevoluteJointBuilder::new()
                    .local_anchor1(rapier2d::math::Vec2::new(0.0, 0.0))
                    .local_anchor2(rapier2d::math::Vec2::new(0.0, 0.0))
                    .build();
                let join_handle = world.impulse_joint_set.insert(
                    object1.rigid_body_handle,
                    object2.rigid_body_handle,
                    joint,
                    true,
                );
                Ok(Joint2 {
                    joint: join_handle,
                    world: Rc::downgrade(&lua_world.0),
                })
            }
        });
    })?;

    // MARK: Join2 fn
    lua.register_userdata_type::<Joint2>(|registry| {
        registry.add_method_mut("remove", |_, joint, (): ()| {
            let Some(world) = joint.world.upgrade() else {
                return Ok(());
            };
            let mut world = world.borrow_mut();
            let world = &mut *world;
            world.impulse_joint_set.remove(joint.joint, true);
            Ok(())
        });
        registry.add_method_mut("getObject1", |_, joint, (): ()| {
            let Some(world) = joint.world.upgrade() else {
                return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
                    "Joint is invalid".to_string(),
                ));
            };
            let mut world = world.borrow_mut();
            let world = &mut *world;
            let Some(j) = world.impulse_joint_set.get(joint.joint) else {
                return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
                    "Joint is invalid".to_string(),
                ));
            };
            world.object(j.body1()).ok_or_else(|| {
                vectarine_plugin_sdk::mlua::Error::RuntimeError("Joint is invalid".to_string())
            })
        });
        registry.add_method_mut("getObject2", |_, joint, (): ()| {
            let Some(world) = joint.world.upgrade() else {
                return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
                    "Joint is invalid".to_string(),
                ));
            };
            let mut world = world.borrow_mut();
            let world = &mut *world;
            let Some(j) = world.impulse_joint_set.get(joint.joint) else {
                return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
                    "Joint is invalid".to_string(),
                ));
            };
            world.object(j.body2()).ok_or_else(|| {
                vectarine_plugin_sdk::mlua::Error::RuntimeError("Joint is invalid".to_string())
            })
        });
    })?;

    // MARK: Collider2 fn
    add_fn_to_table(lua, &physics_module, "newRectangleCollider", {
        move |_, size: Vec2| {
            let collider = ColliderBuilder::cuboid(size.x(), size.y()).build();
            Ok(Collider2 { collider })
        }
    });

    add_fn_to_table(lua, &physics_module, "newCircleCollider", {
        move |_, radius: f32| {
            let collider = ColliderBuilder::ball(radius).build();
            Ok(Collider2 { collider })
        }
    });

    add_fn_to_table(lua, &physics_module, "newPolygonCollider", {
        move |_, points: Vec<Vec2>| {
            let mut converted_points = points // We could probably transmute here, but we won't.
                .iter()
                .map(|p| rapier2d::math::Vec2::new(p.x(), p.y()))
                .collect::<Vec<_>>();
            converted_points.push(converted_points[0]);
            let indices = (0..(points.len() as u32)).map(|i| [i, i + 1]).collect();
            let collider = ColliderBuilder::polyline(converted_points, Some(indices)).build();
            Ok(Collider2 { collider })
        }
    });

    add_fn_to_table(lua, &physics_module, "newVoxelCollider", {
        let resources = resources.clone();
        move |_,
              (voxel_size, tilemap_ud, layer, low, high, filled_tile_ids): (
            Vec2,
            AnyUserData,
            i32,
            Vec2,
            Vec2,
            Vec<i32>,
        )| {
            // We need to write this in a weird way because
            fn fill_voxel_data<T: Tilemap>(
                tilemap: &mut T,
                resources: &Rc<ResourceManager>,
                layer: i32,
                lx: i32,
                ly: i32,
                hx: i32,
                hy: i32,
                filled_tile_ids: &[i32],
                voxel_data: &mut Vec<rapier2d::math::IVector>,
            ) -> vectarine_plugin_sdk::mlua::Result<()> {
                tilemap.get_tile_part(resources, layer, lx, ly, hx, hy, |id, x, y| {
                    if filled_tile_ids.contains(&(id as i32)) {
                        voxel_data.push(rapier2d::math::IVector::new(x, y));
                    }
                    Ok(())
                })
            }

            let lx = low.x().floor() as i32;
            let ly = low.y().floor() as i32;
            let hx = high.x().ceil() as i32;
            let hy = high.y().ceil() as i32;
            let voxel_size = rapier2d::math::Vec2::new(voxel_size.x(), voxel_size.y());
            let mut voxel_data: Vec<rapier2d::math::IVector> = Vec::new();

            let tilemap_id = tilemap_ud.borrow::<TilemapResourceId>();
            if let Ok(tilemap_id) = tilemap_id {
                let mut tilemap_id = *tilemap_id;
                fill_voxel_data(
                    &mut tilemap_id,
                    &resources,
                    layer,
                    lx,
                    ly,
                    hx,
                    hy,
                    &filled_tile_ids,
                    &mut voxel_data,
                )
            } else {
                tilemap_ud
                    .borrow_mut_scoped::<GeneratedTilemap, vectarine_plugin_sdk::mlua::Result<()>>(
                        |generated_tilemap| {
                            fill_voxel_data(
                                generated_tilemap,
                                &resources,
                                layer,
                                lx,
                                ly,
                                hx,
                                hy,
                                &filled_tile_ids,
                                &mut voxel_data,
                            )
                        },
                    )
                    .flatten()
            }?;

            if voxel_data.is_empty() {
                // Voxel colliders created with no voxels cause NaN in AABB and thus panics.
                // We use a 0-sized ball instead.
                let collider = ColliderBuilder::ball(0.0).build();
                return Ok(Collider2 { collider });
            }

            let collider = ColliderBuilder::voxels(voxel_size, &voxel_data).build();
            Ok(Collider2 { collider })
        }
    });

    // MARK: Object2 fn
    lua.register_userdata_type::<Object2>(|registry| {
        registry.add_field_method_get("position", |_, object| Ok(object.position.clone()));
        registry.add_field_method_set("position", |_, object, position: SharedVec2| {
            let value = position.get()?;
            object.position = position;
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.set_translation(to_rapier(value), true);
            })
        });
        registry.add_field_method_get("speed", |_, object| Ok(object.speed.clone()));
        registry.add_field_method_set("speed", |_, object, speed: SharedVec2| {
            let value = speed.get()?;
            object.speed = speed;
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.set_linvel(to_rapier(value), true);
            })
        });
        registry.add_field_method_get("rotation", |_, object| {
            access_rigid_body_mut(object, |_, rigid_body| rigid_body.rotation().angle())
        });
        registry.add_field_method_set("rotation", |_, object, rotation: f32| {
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.set_rotation(rapier2d::math::Rotation::new(rotation), true);
            })
        });
        registry.add_field_method_get("rotationSpeed", |_, object| {
            access_rigid_body_mut(object, |_, rigid_body| rigid_body.angvel())
        });
        registry.add_field_method_set("rotationSpeed", |_, object, rotation_speed: f32| {
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.set_angvel(rotation_speed, true);
            })?;
            Ok(())
        });
        registry.add_field_method_set("linearDamping", |_, object, damping: f32| {
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.set_linear_damping(damping);
            })?;
            Ok(())
        });
        registry.add_field_method_get("linearDamping", |_, object| {
            access_rigid_body_mut(object, |_, rigid_body| rigid_body.linear_damping())
        });
        registry.add_field_method_set("angularDamping", |_, object, damping: f32| {
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.set_angular_damping(damping);
            })?;
            Ok(())
        });
        registry.add_field_method_get("angularDamping", |_, object| {
            access_rigid_body_mut(object, |_, rigid_body| rigid_body.angular_damping())
        });

        registry.add_method_mut("setRestitution", |_, object, restitution: f32| {
            access_rigid_body_mut(object, |collider_set, rigid_body| {
                rigid_body.colliders().iter().for_each(|collider_handle| {
                    let Some(collider) = collider_set.get_mut(*collider_handle) else {
                        return;
                    };
                    collider.set_restitution(restitution);
                });
            })?;
            Ok(())
        });

        registry.add_method_mut("setMass", |_, object, mass: f32| {
            access_rigid_body_mut(object, |collider_set, rigid_body| {
                rigid_body.colliders().iter().for_each(|collider_handle| {
                    let Some(collider) = collider_set.get_mut(*collider_handle) else {
                        return;
                    };
                    // Under the assumption one collider per body
                    collider.set_mass(mass);
                });
            })?;
            Ok(())
        });

        registry.add_method_mut("setFriction", |_, object, friction: f32| {
            access_rigid_body_mut(object, |collider_set, rigid_body| {
                rigid_body.colliders().iter().for_each(|collider_handle| {
                    let Some(collider) = collider_set.get_mut(*collider_handle) else {
                        return;
                    };
                    collider.set_friction(friction);
                });
            })?;
            Ok(())
        });

        registry.add_method("setLockRotation", |_, object, lock: bool| {
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.lock_rotations(lock, true)
            })?;
            Ok(())
        });
        registry.add_method("setLockTranslation", |_, object, lock: bool| {
            access_rigid_body_mut(object, |_, rigid_body| {
                rigid_body.lock_translations(lock, true)
            })?;
            Ok(())
        });

        // ---

        registry.add_field_method_get("tags", |_lua, object| {
            access_extras(object, |extra_object_data| {
                Ok(extra_object_data.tags.clone())
            })
            .flatten()
        });
        registry.add_field_method_set(
            "tags",
            |_, object, tags: vectarine_plugin_sdk::mlua::Table| {
                access_extras(object, |extra_object_data| {
                    extra_object_data.tags = tags;
                })
            },
        );
        registry.add_field_method_get("extra", |_lua, object| {
            access_extras(object, |extra_object_data| {
                Ok(extra_object_data.extra_custom.clone())
            })
            .flatten()
        });
        registry.add_field_method_set(
            "extra",
            |_, object, extra: vectarine_plugin_sdk::mlua::Value| {
                access_extras(object, |extra_object_data| {
                    extra_object_data.extra_custom = extra;
                })
            },
        );
        registry.add_method("getPoints", |lua, object, (): ()| {
            let points = access_rigid_body_mut(object, |collider_set, rigid_body| {
                rigid_body
                    .colliders()
                    .iter()
                    .flat_map(|collider| {
                        let Some(c) = collider_set.get(*collider) else {
                            return Vec::new();
                        };
                        get_points_of_collider(c)
                    })
                    .collect::<Vec<Vec2>>()
            })?;
            let table = lua.create_table()?;
            for point in points {
                table.raw_push(point)?;
            }
            Ok(table)
        });
        registry.add_method("getContacts", |_, object, (): ()| {
            let touching_objects = access_rigid_body(object, |world, rigid_body| {
                let filter = QueryFilter::default();
                let query_pipeline = world.broad_phase.as_query_pipeline(
                    world.narrow_phase.query_dispatcher(),
                    &world.rigid_body_set,
                    &world.collider_set,
                    filter,
                );

                let mut touching_objects = rigid_body
                    .colliders()
                    .iter()
                    .filter_map(|collider| {
                        let c = world.collider_set.get(*collider)?;
                        let intersections =
                            query_pipeline.intersect_shape(*rigid_body.position(), c.shape());
                        Some(intersections.filter_map(|(_, collider)| collider.parent()))
                    })
                    .flatten()
                    .collect::<Vec<_>>();
                touching_objects.sort_by_key(|a| a.0);
                touching_objects.dedup();
                touching_objects
                    .iter()
                    .filter_map(|handle| world.object(*handle))
                    .collect::<Vec<_>>()
            })?;
            Ok(touching_objects)
        });
    })?;

    Ok(physics_module)
}

fn get_points_of_collider(collider: &Collider) -> Vec<Vec2> {
    let shape = collider.shape();
    if let Some(shape) = shape.as_cuboid() {
        shape
            .to_polyline()
            .iter()
            .map(|p| collider.position() * *p)
            .map(|p| Vec2::new(p.x, p.y))
            .collect()
    } else if let Some(shape) = shape.as_ball() {
        shape
            .to_polyline(32)
            .iter()
            .map(|p| collider.position() * *p)
            .map(|p| Vec2::new(p.x, p.y))
            .collect()
    } else if let Some(shape) = shape.as_polyline() {
        shape
            .vertices()
            .iter()
            .map(|p| collider.position() * *p)
            .map(|p| Vec2::new(p.x, p.y))
            .collect()
    } else if let Some(shape) = shape.as_convex_polygon() {
        shape
            .points()
            .iter()
            .map(|p| collider.position() * *p)
            .map(|p| Vec2::new(p.x, p.y))
            .collect()
    } else if let Some(shape) = shape.as_voxels() {
        let size = shape.voxel_size();
        let collider_pos = collider.position();
        shape
            .voxels()
            .flat_map(|p| {
                let center = p.center;
                let p1 =
                    rapier2d::math::Vec2::new(p.center.x - size.x / 2.0, p.center.y - size.y / 2.0);
                let p2 =
                    rapier2d::math::Vec2::new(center.x + size.x / 2.0, center.y - size.y / 2.0);
                let p3 =
                    rapier2d::math::Vec2::new(p.center.x + size.x / 2.0, p.center.y + size.y / 2.0);
                let p4 =
                    rapier2d::math::Vec2::new(center.x - size.x / 2.0, center.y + size.y / 2.0);
                vec![
                    collider_pos * p1,
                    collider_pos * p2,
                    collider_pos * p3,
                    collider_pos * p4,
                ]
            })
            .map(|p| Vec2::new(p.x, p.y))
            .collect()
    } else {
        // As a fallback, we use the AABB
        let aabb = shape.compute_aabb(collider.position());
        vec![
            Vec2::new(aabb.maxs.x, aabb.maxs.y),
            Vec2::new(aabb.maxs.x, aabb.mins.y),
            Vec2::new(aabb.mins.x, aabb.mins.y),
            Vec2::new(aabb.mins.x, aabb.maxs.y),
        ]
    }
}

fn access_rigid_body_mut<F, T>(object: &Object2, f: F) -> vectarine_plugin_sdk::mlua::Result<T>
where
    F: FnOnce(&mut ColliderSet, &mut RigidBody) -> T,
{
    let maybe_world = object.world.upgrade();
    let Some(world) = maybe_world else {
        return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
            "Object2 is out of this world".to_string(),
        ));
    };
    let world = &mut *world.borrow_mut();
    let Some(rigid_body) = world.rigid_body_set.get_mut(object.rigid_body_handle) else {
        return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
            "Object2 is out of this world".to_string(),
        ));
    };
    Ok(f(&mut world.collider_set, rigid_body))
}

fn access_rigid_body<F, T>(object: &Object2, f: F) -> vectarine_plugin_sdk::mlua::Result<T>
where
    F: FnOnce(&PhysicsWorld2, &RigidBody) -> T,
{
    let maybe_world = object.world.upgrade();
    let Some(world) = maybe_world else {
        return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
            "Object2 is out of this world".to_string(),
        ));
    };
    let world = &*world.borrow();
    let Some(rigid_body) = world.rigid_body_set.get(object.rigid_body_handle) else {
        return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
            "Object2 is out of this world".to_string(),
        ));
    };
    Ok(f(world, rigid_body))
}

fn access_extras<F, T>(object: &Object2, f: F) -> vectarine_plugin_sdk::mlua::Result<T>
where
    F: FnOnce(&mut ExtraObjectData) -> T,
{
    let maybe_world = object.world.upgrade();
    let Some(world) = maybe_world else {
        return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
            "Object2 is out of this world".to_string(),
        ));
    };
    let world = &mut *world.borrow_mut();
    let extras = world.extras.get_mut(&object.rigid_body_handle);
    let Some(extras) = extras else {
        return Err(vectarine_plugin_sdk::mlua::Error::RuntimeError(
            "Object2 is out of this world".to_string(),
        ));
    };
    Ok(f(extras))
}

#[cfg(test)]
mod tests {
    use std::{path::Path, rc::Rc};

    use vectarine_plugin_sdk::mlua::{Lua, Result};

    use crate::{game_resource::ResourceManager, io::dummyfs::DummyFileSystem};

    #[test]
    fn position_and_speed_are_shared() -> Result<()> {
        let lua = Lua::new();
        let resources = Rc::new(ResourceManager::new(
            Box::new(DummyFileSystem),
            Path::new(""),
        ));
        let globals = lua.globals();
        globals.set("vec", crate::lua_env::lua_vec2::setup_vec_api(&lua)?)?;
        globals.set("physics", super::setup_physics_api(&lua, &resources)?)?;
        lua.load(
            r#"
            local world = physics.newWorld2(vec.V2(0, -10))
            local spawn = vec.V2(0, 0)
            local box = world:createObject(spawn, 1, physics.newRectangleCollider(vec.V2(1, 1)), { "box" }, "dynamic")
            assert(rawequal(world:getObjects({ "box" })[1], box))

            local p = box.position
            p.x = 5
            world:step(1 / 60)
            assert(rawequal(box.position, p) and p.x == 5 and p.y < 0)
            assert(spawn.x == 0 and spawn.y == 0)
            assert(rawequal(world:getObjectsAtPoint(p)[1], box))

            box.speed.x = 60
            world:step(1 / 60)
            assert(box.position.x > 5.9 and box.position.x < 6.1)

            local a = vec.V2(100, 0)
            box.position = a
            assert(box.position.x == 100)
            a.x = 200
            world:step(1 / 60)
            assert(rawequal(box.position, a) and a.x > 200)

            box.speed = vec.ZERO2
            box.speed.x = 1
            assert(vec.ZERO2.x == 0)

            world:removeObject(box)
            assert(#world:getObjects() == 0)
            assert(not pcall(function() return box.rotation end))
            "#,
        )
        .exec()
    }
}
