using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Камера. В меню медленно облетает пасеку (живое 3D-меню),
    /// в вылете смотрит на пчелу сверху под углом и не поворачивается,
    /// чтобы управление пальцем всегда было одинаковым.
    /// </summary>
    public class FollowCamera : MonoBehaviour
    {
        public Vector3 offset = new Vector3(0f, 11.5f, -8.5f);
        public float followSmooth = 0.18f;

        World _world;
        Transform _target;
        bool _hub = true;
        float _orbit = -20f;
        Vector3 _velocity;

        public static FollowCamera Setup(World world)
        {
            var cam = Camera.main;
            if (cam == null)
            {
                var go = new GameObject("Main Camera") { tag = "MainCamera" };
                cam = go.AddComponent<Camera>();
                go.AddComponent<AudioListener>();
            }
            cam.fieldOfView = 50f;
            cam.nearClipPlane = 0.2f;
            cam.farClipPlane = 220f;

            var fc = cam.GetComponent<FollowCamera>();
            if (fc == null) fc = cam.gameObject.AddComponent<FollowCamera>();
            fc._world = world;
            fc.ShowHub();
            return fc;
        }

        public void ShowHub()
        {
            _hub = true;
            _target = null;
        }

        public void Follow(Transform target)
        {
            _hub = false;
            _target = target;
            _velocity = Vector3.zero;
            if (target != null)
            {
                transform.position = target.position + offset;
                transform.rotation = FixedRotation();
            }
        }

        Quaternion FixedRotation()
        {
            float angle = Mathf.Atan2(offset.y, -offset.z) * Mathf.Rad2Deg;
            return Quaternion.Euler(angle, 0f, 0f);
        }

        void LateUpdate()
        {
            if (_hub || _target == null)
            {
                Vector3 center = _world != null ? _world.HivePosition : Vector3.zero;
                _orbit += 6f * Time.deltaTime;
                Vector3 desired = center + Quaternion.Euler(0f, _orbit, 0f) * new Vector3(0f, 4.2f, -9f);
                transform.position = Vector3.Lerp(transform.position, desired, 2f * Time.deltaTime);
                Quaternion look = Quaternion.LookRotation(center + Vector3.up * 1.6f - transform.position);
                transform.rotation = Quaternion.Slerp(transform.rotation, look, 3f * Time.deltaTime);
                return;
            }

            Vector3 goal = _target.position + offset;
            goal.y = offset.y + 1.5f; // не прыгаем по высоте, когда пчела ныряет к цветку
            transform.position = Vector3.SmoothDamp(transform.position, goal, ref _velocity, followSmooth);
            transform.rotation = FixedRotation();
        }
    }
}
