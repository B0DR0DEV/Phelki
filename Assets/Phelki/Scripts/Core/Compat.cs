using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Совместимость между Unity 2022 и Unity 6: в Unity 6 переименовали
    /// скорость и затухание Rigidbody и физический материал.
    /// </summary>
    public static class Compat
    {
        public static Vector3 Vel(this Rigidbody rb)
        {
#if UNITY_6000_0_OR_NEWER
            return rb.linearVelocity;
#else
            return rb.velocity;
#endif
        }

        public static void SetVel(this Rigidbody rb, Vector3 v)
        {
#if UNITY_6000_0_OR_NEWER
            rb.linearVelocity = v;
#else
            rb.velocity = v;
#endif
        }

        public static void SetDamping(this Rigidbody rb, float linear, float angular)
        {
#if UNITY_6000_0_OR_NEWER
            rb.linearDamping = linear;
            rb.angularDamping = angular;
#else
            rb.drag = linear;
            rb.angularDrag = angular;
#endif
        }

#if UNITY_6000_0_OR_NEWER
        public static PhysicsMaterial Bouncy(float bounciness)
        {
            return new PhysicsMaterial("Bouncy")
            {
                bounciness = bounciness,
                dynamicFriction = 0.05f,
                staticFriction = 0.05f,
                bounceCombine = PhysicsMaterialCombine.Maximum,
                frictionCombine = PhysicsMaterialCombine.Minimum
            };
        }
#else
        public static PhysicMaterial Bouncy(float bounciness)
        {
            return new PhysicMaterial("Bouncy")
            {
                bounciness = bounciness,
                dynamicFriction = 0.05f,
                staticFriction = 0.05f,
                bounceCombine = PhysicMaterialCombine.Maximum,
                frictionCombine = PhysicMaterialCombine.Minimum
            };
        }
#endif
    }
}
