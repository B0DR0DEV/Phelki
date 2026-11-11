using System.Collections.Generic;
using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Как пчела выглядит в движении: поворот по курсу, крен в виражах,
    /// кувырок при ударе, толстеет от пыльцы, вытягивается в рывке, машет крыльями.
    /// Работает и с заглушкой, и с настоящей моделью.
    /// </summary>
    public class BeeVisual : MonoBehaviour
    {
        BeeController _bee;
        Transform[] _wings = new Transform[0];
        Vector3 _baseScale;
        Vector3 _lastHoriz;
        float _yaw, _roll, _tumbleUntil, _dashPulse;
        const float TumbleTime = 0.6f;

        public void Bind(BeeController bee)
        {
            _bee = bee;
            _baseScale = transform.localScale;
            _wings = FindWings(transform);
        }

        public static Transform[] FindWings(Transform root)
        {
            var list = new List<Transform>();
            foreach (var t in root.GetComponentsInChildren<Transform>())
                if (t.name.StartsWith("Крыло")) list.Add(t);
            return list.ToArray();
        }

        public void Tumble() => _tumbleUntil = Time.time + TumbleTime;
        public void Dash() => _dashPulse = 1f;

        void LateUpdate()
        {
            if (_bee == null) return;
            float dt = Mathf.Max(Time.deltaTime, 0.0001f);

            Vector3 v = _bee.Velocity;
            Vector3 h = new Vector3(v.x, 0f, v.z);
            if (h.sqrMagnitude > 0.3f)
                _yaw = Mathf.LerpAngle(_yaw, Mathf.Atan2(h.x, h.z) * Mathf.Rad2Deg, 10f * dt);

            Vector3 accel = (h - _lastHoriz) / dt;
            _lastHoriz = h;
            float lateral = Vector3.Dot(accel, Quaternion.Euler(0f, _yaw, 0f) * Vector3.right);
            _roll = Mathf.Lerp(_roll, Mathf.Clamp(-lateral * 1.5f, -35f, 35f), 6f * dt);
            float pitch = Mathf.Clamp(h.magnitude * 2.2f, 0f, 22f);

            Quaternion rot = Quaternion.Euler(pitch, _yaw, _roll);
            if (Time.time < _tumbleUntil)
            {
                float k = 1f - (_tumbleUntil - Time.time) / TumbleTime;
                rot *= Quaternion.Euler(k * 360f, 0f, k * 200f);
            }
            if (_bee.IsStuck) rot *= Quaternion.Euler(0f, 0f, Mathf.Sin(Time.time * 25f) * 12f);
            transform.rotation = rot;

            float fat = 1f + _bee.Load * 0.35f;
            _dashPulse = Mathf.MoveTowards(_dashPulse, 0f, dt * 3f);
            float squeeze = 1f - _dashPulse * 0.2f;
            transform.localScale = new Vector3(
                _baseScale.x * fat * squeeze,
                _baseScale.y * fat * squeeze,
                _baseScale.z * (1f + _dashPulse * 0.35f));

            float flap = Mathf.Sin(Time.time * (_bee.IsStuck ? 12f : 55f)) * 50f;
            foreach (var w in _wings)
            {
                float side = w.localPosition.x >= 0f ? 1f : -1f;
                w.localEulerAngles = new Vector3(0f, side * -15f, side * flap);
            }
        }

        /// <summary>
        /// Временная пчела (или оса) из простых форм. Смотрит вперёд по оси Z.
        /// Заменяется настоящей моделью через PhelkiArtSet.
        /// </summary>
        public static void BuildPlaceholder(Transform root, bool wasp)
        {
            const PrimitiveType S = PrimitiveType.Sphere;
            const PrimitiveType C = PrimitiveType.Cylinder;
            const PrimitiveType B = PrimitiveType.Cube;

            Color body = wasp ? new Color(0.98f, 0.76f, 0.08f) : Palette.BeeYellow;
            Color dark = Palette.Black;
            Color thorax = wasp ? dark : new Color(0.30f, 0.20f, 0.10f);

            // Брюшко с полосками
            Vector3 abdomenScale = wasp ? new Vector3(0.38f, 0.36f, 0.62f) : new Vector3(0.5f, 0.46f, 0.68f);
            Shape.Make(S, root, new Vector3(0f, 0f, -0.12f), abdomenScale, body, false, "Брюшко");
            float sx = abdomenScale.x, sy = abdomenScale.y;
            Shape.Make(C, root, new Vector3(0f, 0f, -0.04f), new Vector3(sx * 1.0f, 0.035f, sy * 1.0f), dark, false,
                "Полоска", new Vector3(90f, 0f, 0f));
            Shape.Make(C, root, new Vector3(0f, 0f, -0.20f), new Vector3(sx * 0.93f, 0.035f, sy * 0.93f), dark, false,
                "Полоска", new Vector3(90f, 0f, 0f));
            Shape.Make(C, root, new Vector3(0f, 0f, -0.33f), new Vector3(sx * 0.72f, 0.03f, sy * 0.72f), dark, false,
                "Полоска", new Vector3(90f, 0f, 0f));

            // Грудь, голова, жало
            Shape.Make(S, root, new Vector3(0f, 0.02f, 0.2f), new Vector3(0.36f, 0.34f, 0.34f), thorax, false, "Грудь");
            Shape.Make(S, root, new Vector3(0f, 0.05f, 0.42f), new Vector3(0.3f, 0.28f, 0.26f), dark, false, "Голова");
            Shape.Make(PrimitiveType.Capsule, root, new Vector3(0f, -0.02f, -0.5f), new Vector3(0.05f, 0.07f, 0.05f), dark,
                false, "Жало", new Vector3(90f, 0f, 0f));

            // Глаза
            Color pupil = wasp ? Palette.Red : dark;
            float eyeSize = wasp ? 0.09f : 0.12f;
            Shape.Make(S, root, new Vector3(-0.08f, 0.1f, 0.53f), Vector3.one * eyeSize, Palette.White, false, "Глаз");
            Shape.Make(S, root, new Vector3(0.08f, 0.1f, 0.53f), Vector3.one * eyeSize, Palette.White, false, "Глаз");
            Shape.Make(S, root, new Vector3(-0.085f, 0.1f, 0.585f), Vector3.one * 0.055f, pupil, false, "Зрачок");
            Shape.Make(S, root, new Vector3(0.085f, 0.1f, 0.585f), Vector3.one * 0.055f, pupil, false, "Зрачок");

            // Усики
            Shape.Make(C, root, new Vector3(-0.06f, 0.22f, 0.47f), new Vector3(0.02f, 0.1f, 0.02f), dark, false, "Усик",
                new Vector3(-30f, 0f, 20f));
            Shape.Make(C, root, new Vector3(0.06f, 0.22f, 0.47f), new Vector3(0.02f, 0.1f, 0.02f), dark, false, "Усик",
                new Vector3(-30f, 0f, -20f));

            // Крылья на шарнирах (машут вокруг плеча)
            for (int i = 0; i < 2; i++)
            {
                float side = i == 0 ? -1f : 1f;
                var pivot = Shape.Node(i == 0 ? "Крыло_Л" : "Крыло_П", root, new Vector3(0.12f * side, 0.2f, 0.15f));
                Shape.Make(S, pivot, new Vector3(0.22f * side, 0.02f, -0.05f), new Vector3(0.42f, 0.02f, 0.24f),
                    Palette.Wing, false, "Перепонка");
            }

            if (!wasp) return;

            // Оса-гопник: кепка и злые брови
            Color cap = new Color(0.22f, 0.22f, 0.25f);
            Shape.Make(C, root, new Vector3(0f, 0.2f, 0.42f), new Vector3(0.26f, 0.03f, 0.26f), cap, false, "Кепка");
            Shape.Make(B, root, new Vector3(0f, 0.19f, 0.56f), new Vector3(0.2f, 0.02f, 0.12f), cap, false, "Козырёк");
            Shape.Make(B, root, new Vector3(-0.08f, 0.165f, 0.57f), new Vector3(0.1f, 0.02f, 0.02f), dark, false, "Бровь",
                new Vector3(0f, 0f, -20f));
            Shape.Make(B, root, new Vector3(0.08f, 0.165f, 0.57f), new Vector3(0.1f, 0.02f, 0.02f), dark, false, "Бровь",
                new Vector3(0f, 0f, 20f));
        }
    }
}
