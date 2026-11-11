using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Вид дачника: майка, шорты, шлёпанцы, панамка и мухобойка.
    /// Бег (машет руками и ногами), перекат, замах мухобойкой, вздрагивание
    /// от укуса. С каждым укусом голова и руки раздуваются и краснеют.
    /// </summary>
    public class HumanVisual : MonoBehaviour
    {
        static readonly Color Skin = new Color(0.98f, 0.80f, 0.66f);
        static readonly Color Swollen = new Color(0.95f, 0.42f, 0.40f);
        static readonly Color Tank = new Color(0.97f, 0.97f, 0.95f);
        static readonly Color Shorts = new Color(0.20f, 0.45f, 0.80f);
        static readonly Color Slippers = new Color(0.15f, 0.65f, 0.35f);
        static readonly Color Panama = new Color(0.86f, 0.80f, 0.60f);

        HumanController _human;
        Transform _body, _head, _legL, _legR, _armL, _armR;
        Renderer[] _skin = new Renderer[0];
        bool _placeholder;
        float _runPhase, _rollStart, _rollEnd, _swingStart = -10f, _flinchStart = -10f, _faintStart = -1f;
        int _skinStep = -1;

        public void Build(HumanController human)
        {
            _human = human;
            _body = Shape.Node("Тело", transform, Vector3.zero);

            var art = PhelkiArtSet.Current;
            if (art != null && art.human != null)
            {
                Shape.PlaceModel(art.human, _body, Vector3.zero, 0f, false);
                return;
            }
            _placeholder = true;

            const PrimitiveType S = PrimitiveType.Sphere;
            const PrimitiveType C = PrimitiveType.Cylinder;
            const PrimitiveType B = PrimitiveType.Cube;

            // Ноги (шарнир в бедре)
            _legL = Shape.Node("Нога_Л", _body, new Vector3(-0.15f, 0.88f, 0f));
            _legR = Shape.Node("Нога_П", _body, new Vector3(0.15f, 0.88f, 0f));
            var legSkin1 = Shape.Make(C, _legL, new Vector3(0f, -0.42f, 0f), new Vector3(0.15f, 0.4f, 0.15f), Skin);
            var legSkin2 = Shape.Make(C, _legR, new Vector3(0f, -0.42f, 0f), new Vector3(0.15f, 0.4f, 0.15f), Skin);
            Shape.Make(B, _legL, new Vector3(0f, -0.84f, 0.06f), new Vector3(0.16f, 0.05f, 0.32f), Slippers, false, "Шлёпанец");
            Shape.Make(B, _legR, new Vector3(0f, -0.84f, 0.06f), new Vector3(0.16f, 0.05f, 0.32f), Slippers, false, "Шлёпанец");

            // Шорты, майка, пузо
            Shape.Make(B, _body, new Vector3(0f, 0.98f, 0f), new Vector3(0.52f, 0.32f, 0.34f), Shorts, false, "Шорты");
            Shape.Make(PrimitiveType.Capsule, _body, new Vector3(0f, 1.42f, 0f), new Vector3(0.56f, 0.36f, 0.38f), Tank, false, "Майка");
            Shape.Make(S, _body, new Vector3(0f, 1.28f, 0.08f), new Vector3(0.52f, 0.48f, 0.42f), Tank, false, "Пузо");

            // Руки (шарнир в плече)
            _armL = Shape.Node("Рука_Л", _body, new Vector3(-0.36f, 1.68f, 0f));
            _armR = Shape.Node("Рука_П", _body, new Vector3(0.36f, 1.68f, 0f));
            var armSkin1 = Shape.Make(C, _armL, new Vector3(0f, -0.3f, 0f), new Vector3(0.12f, 0.3f, 0.12f), Skin);
            var armSkin2 = Shape.Make(C, _armR, new Vector3(0f, -0.3f, 0f), new Vector3(0.12f, 0.3f, 0.12f), Skin);

            // Мухобойка в правой руке
            Shape.Make(C, _armR, new Vector3(0f, -0.62f, 0.18f), new Vector3(0.03f, 0.22f, 0.03f), Palette.Metal, false, "Ручка",
                new Vector3(90f, 0f, 0f));
            Shape.Make(B, _armR, new Vector3(0f, -0.62f, 0.5f), new Vector3(0.24f, 0.02f, 0.24f), Palette.Red, false, "Хлопушка");

            // Голова, нос, глаза, усы, панамка
            _head = Shape.Node("Голова", _body, new Vector3(0f, 1.98f, 0f));
            var face = Shape.Make(S, _head, Vector3.zero, new Vector3(0.44f, 0.46f, 0.42f), Skin, false, "Лицо");
            var nose = Shape.Make(S, _head, new Vector3(0f, -0.02f, 0.22f), new Vector3(0.11f, 0.1f, 0.1f), Skin, false, "Нос");
            Shape.Make(S, _head, new Vector3(-0.09f, 0.06f, 0.19f), Vector3.one * 0.06f, Palette.Black, false, "Глаз");
            Shape.Make(S, _head, new Vector3(0.09f, 0.06f, 0.19f), Vector3.one * 0.06f, Palette.Black, false, "Глаз");
            Shape.Make(B, _head, new Vector3(0f, -0.09f, 0.2f), new Vector3(0.18f, 0.035f, 0.04f), new Color(0.35f, 0.25f, 0.15f), false, "Усы");
            Shape.Make(C, _head, new Vector3(0f, 0.2f, 0f), new Vector3(0.62f, 0.02f, 0.62f), Panama, false, "Поля панамки");
            Shape.Make(C, _head, new Vector3(0f, 0.27f, 0f), new Vector3(0.38f, 0.08f, 0.38f), Panama, false, "Панамка");

            _skin = new[]
            {
                legSkin1.GetComponent<Renderer>(), legSkin2.GetComponent<Renderer>(),
                armSkin1.GetComponent<Renderer>(), armSkin2.GetComponent<Renderer>(),
                face.GetComponent<Renderer>(), nose.GetComponent<Renderer>()
            };
        }

        public void Roll(float duration)
        {
            _rollStart = Time.time;
            _rollEnd = Time.time + duration;
        }

        public void Swing() => _swingStart = Time.time;
        public void Flinch() => _flinchStart = Time.time;

        /// <summary>Падает на спину (концовка «увезли на скорой»).</summary>
        public void Faint() => _faintStart = Time.time;

        void LateUpdate()
        {
            if (_human == null) return;
            float dt = Time.deltaTime;

            // Поворот по курсу и перекат
            Quaternion rot = Quaternion.Euler(0f, _human.Facing, 0f);
            if (Time.time < _rollEnd)
            {
                float k = Mathf.InverseLerp(_rollStart, _rollEnd, Time.time);
                rot *= Quaternion.Euler(k * 360f, 0f, 0f);
            }
            if (_faintStart >= 0f)
            {
                float k = Mathf.Clamp01((Time.time - _faintStart) / 0.5f);
                rot *= Quaternion.Euler(-90f * Mathf.SmoothStep(0f, 1f, k), 0f, 0f);
            }
            transform.rotation = Quaternion.Slerp(transform.rotation, rot,
                Time.time < _rollEnd || _faintStart >= 0f ? 1f : 14f * dt);

            // Вздрагивание от укуса
            float ft = Time.time - _flinchStart;
            float jolt = ft < 0.25f ? Mathf.Sin(ft / 0.25f * Mathf.PI) * 0.12f : 0f;
            transform.localPosition = new Vector3(0f, jolt, 0f);

            if (!_placeholder) return;

            // Бег: ноги и руки
            Vector3 v = _human.Velocity;
            float speed = new Vector3(v.x, 0f, v.z).magnitude;
            _runPhase += speed * dt * 2.4f;
            float swing = Mathf.Sin(_runPhase) * Mathf.Clamp01(speed / 4f) * 40f;
            _legL.localRotation = Quaternion.Euler(swing, 0f, 0f);
            _legR.localRotation = Quaternion.Euler(-swing, 0f, 0f);
            _armL.localRotation = Quaternion.Euler(-swing * 0.8f, 0f, -8f);

            // Замах мухобойкой поверх бега
            float st = Time.time - _swingStart;
            if (st < 0.3f)
            {
                float k = st / 0.3f;
                float angle = k < 0.35f ? Mathf.Lerp(0f, -150f, k / 0.35f) : Mathf.Lerp(-150f, 40f, (k - 0.35f) / 0.65f);
                _armR.localRotation = Quaternion.Euler(angle, 0f, 8f);
            }
            else _armR.localRotation = Quaternion.Euler(swing * 0.8f, 0f, 8f);

            // Отёк: голова и руки раздуваются и краснеют
            float s = _human.Swelling;
            _head.localScale = Vector3.one * (1f + s * 0.75f);
            float armFat = 1f + s * 0.7f;
            _armL.localScale = new Vector3(armFat, 1f, armFat);
            _armR.localScale = new Vector3(armFat, 1f, armFat);

            int step = Mathf.RoundToInt(s * 10f);
            if (step != _skinStep)
            {
                _skinStep = step;
                var m = Shape.Mat(Color.Lerp(Skin, Swollen, step / 10f));
                foreach (var r in _skin) r.sharedMaterial = m;
            }
        }
    }
}
