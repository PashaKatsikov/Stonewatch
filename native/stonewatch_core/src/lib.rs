//! Game math for Stonewatch: landing rules, wallet arithmetic, the
//! round dice and the swing / fall kinematics. The Flutter side only
//! renders; every number that decides a round comes from here.

#[macro_use]
pub mod veil;
pub mod dice;
pub mod economy;
pub mod ffi;
pub mod mask;
pub mod motion;
pub mod rules;
pub mod vault;
