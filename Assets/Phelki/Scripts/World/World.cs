using System.Collections.Generic;
using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Дачный участок: строится кодом из временных моделей. Любой объект можно
    /// заменить настоящей моделью через PhelkiArtSet — логика останется.
    /// Ориентация: камера смотрит вдоль +Z, улей в центре, вход улья к камере.
    /// </summary>
    public class World : MonoBehaviour
    {
        public const float Half = 32f;

        public Transform Dynamic { get; private set; }
        public Transform BeeSpawn { get; private set; }
        public Vector3 HivePosition { get; private set; }
        public Vector3 Wind { get; private set; }

        readonly List<Flower> _flowers = new List<Flower>();
        readonly List<Wasp> _wasps = new List<Wasp>();
        Swarm _swarm;
        PhelkiArtSet _art;
        System.Random _rng;

        Vector3 _gustDir;
        float _gustStart, _gustEnd, _nextGust;

        static readonly Color[] PetalColors =
        {
            new Color(0.96f, 0.45f, 0.65f), new Color(0.98f, 0.98f, 0.96f), new Color(0.62f, 0.42f, 0.88f),
            new Color(0.95f, 0.30f, 0.25f), new Color(1.00f, 0.60f, 0.20f), new Color(0.40f, 0.62f, 0.98f)
        };

        public static World Build(Transform parent)
        {
            var go = new GameObject("Дача");
            go.transform.SetParent(parent, false);
            var w = go.AddComponent<World>();
            w.BuildAll();
            return w;
        }

        void BuildAll()
        {
            _art = PhelkiArtSet.Current;
            _rng = new System.Random(2026);

            Dynamic = Shape.Node("Динамика", transform, Vector3.zero);
            SetupLighting();
            BuildGround();
            BuildBounds();

            HivePosition = Vector3.zero;
            BuildHive(HivePosition);
            BeeSpawn = Shape.Node("Старт пчелы", transform, new Vector3(0f, 2.1f, -2.4f));

            BuildHouse(new Vector3(-15f, 0f, 13f));
            BuildGreenhouse(new Vector3(13f, 0f, 10f));

            BuildFlowerBed(new Vector3(8f, 0f, -4f), 4.5f, 10, false);
            BuildFlowerBed(new Vector3(-8f, 0f, -7f), 4f, 9, false);
            BuildFlowerBed(new Vector3(-9f, 0f, 4f), 3.2f, 7, true); // бабкины клумбы
            BuildFlowerBed(new Vector3(4f, 0f, 16f), 4f, 9, false);
            BuildFlowerBed(new Vector3(18f, 0f, -14f), 4.5f, 10, false);
            BuildFlowerBed(new Vector3(-20f, 0f, -14f), 4f, 9, false);
            BuildFlowerBed(new Vector3(22f, 0f, 2f), 3.5f, 7, false);

            BuildJamTable(new Vector3(5f, 0f, -12f));
            BuildFan(new Vector3(-3f, 0f, 9f));
            BuildTrashCan(new Vector3(20f, 0f, 18f), 2);
            BuildTrashCan(new Vector3(-24f, 0f, -2f), 1);
            BuildClothesline(new Vector3(-14f, 0f, -22f), new Vector3(0f, 0f, -22f));

            Vector3[] trees =
            {
                new Vector3(-26f, 0f, 25f), new Vector3(-6f, 0f, 26f), new Vector3(14f, 0f, 26f),
                new Vector3(27f, 0f, 9f), new Vector3(27f, 0f, -24f), new Vector3(-27f, 0f, -26f),
                new Vector3(-28f, 0f, 9f), new Vector3(10f, 0f, -25f), new Vector3(12f, 0f, 2f),
                new Vector3(-4f, 0f, -16f), new Vector3(-16f, 0f, -5f)
            };
            foreach (var t in trees) BuildTree(t);

            _swarm = Swarm.Build(transform, HivePosition, 14);
            _swarm.Angry = PlayerProfile.Current.Side == Side.Human;
        }

        // ── Свет и земля ───────────────────────────────────────

        void SetupLighting()
        {
            Light sun = null;
            foreach (var l in FindObjectsByType<Light>(FindObjectsSortMode.None))
                if (l.type == LightType.Directional) { sun = l; break; }

            if (sun == null)
            {
                sun = new GameObject("Солнце").AddComponent<Light>();
                sun.type = LightType.Directional;
            }
            sun.transform.rotation = Quaternion.Euler(48f, -35f, 0f);
            sun.color = new Color(1f, 0.95f, 0.85f);
            sun.intensity = 1.15f;
            sun.shadows = LightShadows.Soft;

            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogColor = new Color(0.78f, 0.88f, 0.96f);
            RenderSettings.fogStartDistance = 45f;
            RenderSettings.fogEndDistance = 110f;
        }

        void BuildGround()
        {
            Shape.Make(PrimitiveType.Cube, transform, new Vector3(0f, -0.5f, 0f),
                new Vector3(Half * 2f + 40f, 1f, Half * 2f + 40f), Palette.Grass, true, "Земля");

            // Дорожки от улья
            Shape.Make(PrimitiveType.Cube, transform, new Vector3(0f, 0.01f, -12f), new Vector3(2.2f, 0.02f, 24f),
                Palette.Path, false, "Дорожка");
            Shape.Make(PrimitiveType.Cube, transform, new Vector3(-8f, 0.012f, 9f), new Vector3(16f, 0.02f, 2f),
                Palette.Path, false, "Дорожка");

            // Пятна травы потемнее — чтобы земля не была плоской
            for (int i = 0; i < 26; i++)
            {
                // Каждое пятно чуть выше предыдущего, чтобы они не мерцали, перекрываясь
                var p = new Vector3(Rand(-Half, Half), 0.004f + i * 0.0003f, Rand(-Half, Half));
                float s = Rand(3f, 7f);
                Shape.Make(PrimitiveType.Cylinder, transform, p, new Vector3(s, 0.005f, s * Rand(0.6f, 1f)),
                    Palette.GrassDark, false, "Трава");
            }

            // Забор по периметру
            var fence = Shape.Node("Забор", transform, Vector3.zero);
            for (float x = -Half; x <= Half + 0.01f; x += 4f)
            {
                FencePost(fence, new Vector3(x, 0f, -Half));
                FencePost(fence, new Vector3(x, 0f, Half));
            }
            for (float z = -Half + 4f; z < Half; z += 4f)
            {
                FencePost(fence, new Vector3(-Half, 0f, z));
                FencePost(fence, new Vector3(Half, 0f, z));
            }
            foreach (float y in new[] { 0.45f, 0.95f })
            {
                Shape.Make(PrimitiveType.Cube, fence, new Vector3(0f, y, -Half), new Vector3(Half * 2f, 0.1f, 0.08f), Palette.Wood);
                Shape.Make(PrimitiveType.Cube, fence, new Vector3(0f, y, Half), new Vector3(Half * 2f, 0.1f, 0.08f), Palette.Wood);
                Shape.Make(PrimitiveType.Cube, fence, new Vector3(-Half, y, 0f), new Vector3(0.08f, 0.1f, Half * 2f), Palette.Wood);
                Shape.Make(PrimitiveType.Cube, fence, new Vector3(Half, y, 0f), new Vector3(0.08f, 0.1f, Half * 2f), Palette.Wood);
            }
        }

        void FencePost(Transform parent, Vector3 p) =>
            Shape.Make(PrimitiveType.Cube, parent, p + Vector3.up * 0.6f, new Vector3(0.14f, 1.2f, 0.14f), Palette.Wood);

        void BuildBounds()
        {
            // Невидимые стены: пчела не улетит с участка
            var b = Shape.Node("Границы", transform, Vector3.zero);
            void Wall(Vector3 c, Vector3 s)
            {
                var go = new GameObject("Стена");
                go.transform.SetParent(b, false);
                go.transform.localPosition = c;
                var box = go.AddComponent<BoxCollider>();
                box.size = s;
            }
            float h = 10f, t = 1f, l = Half * 2f + 2f;
            Wall(new Vector3(0f, h / 2f, -Half - t / 2f), new Vector3(l, h, t));
            Wall(new Vector3(0f, h / 2f, Half + t / 2f), new Vector3(l, h, t));
            Wall(new Vector3(-Half - t / 2f, h / 2f, 0f), new Vector3(t, h, l));
            Wall(new Vector3(Half + t / 2f, h / 2f, 0f), new Vector3(t, h, l));
            Wall(new Vector3(0f, 6f, 0f), new Vector3(l, 0.5f, l)); // потолок
        }

        // ── Пасека ─────────────────────────────────────────────

        void BuildHive(Vector3 pos)
        {
            var root = new GameObject("Улей");
            root.transform.SetParent(transform, false);
            root.transform.localPosition = pos;

            var body = Shape.Node("Корпус", root.transform, Vector3.zero);
            if (_art != null && _art.hive != null)
            {
                Shape.PlaceModel(_art.hive, body, Vector3.zero, 180f);
            }
            else
            {
                // Ножки
                foreach (var lp in new[] { new Vector3(-0.5f, 0.15f, -0.4f), new Vector3(0.5f, 0.15f, -0.4f),
                             new Vector3(-0.5f, 0.15f, 0.4f), new Vector3(0.5f, 0.15f, 0.4f) })
                    Shape.Make(PrimitiveType.Cube, body, lp, new Vector3(0.1f, 0.3f, 0.1f), Palette.Wood);

                // Три корпуса, крыша, леток, прилётная доска
                Color[] tiers = { Palette.WoodLight, new Color(0.98f, 0.82f, 0.45f), Palette.WoodLight };
                for (int i = 0; i < 3; i++)
                    Shape.Make(PrimitiveType.Cube, body, new Vector3(0f, 0.49f + i * 0.38f, 0f),
                        new Vector3(1.2f, 0.36f, 1.0f), tiers[i], false, "Корпус " + (i + 1));
                Shape.Make(PrimitiveType.Cube, body, new Vector3(0f, 1.5f, 0f), new Vector3(1.4f, 0.12f, 1.2f),
                    Palette.Roof, false, "Крыша");
                Shape.Make(PrimitiveType.Cube, body, new Vector3(0f, 0.38f, -0.51f), new Vector3(0.6f, 0.06f, 0.04f),
                    Palette.Black, false, "Леток");
                Shape.Make(PrimitiveType.Cube, body, new Vector3(0f, 0.33f, -0.62f), new Vector3(0.7f, 0.03f, 0.22f),
                    Palette.Wood, false, "Прилётная доска");

                // Твёрдое тело улья — ниже высоты полёта, чтобы над ним можно было пролететь
                var solid = body.gameObject.AddComponent<BoxCollider>();
                solid.center = new Vector3(0f, 0.8f, 0f);
                solid.size = new Vector3(1.2f, 1.25f, 1.0f);
            }

            var hive = root.AddComponent<Hive>();
            hive.Init(body);
            var trigger = root.AddComponent<SphereCollider>();
            trigger.isTrigger = true;
            trigger.center = new Vector3(0f, 1.4f, -0.3f);
            trigger.radius = 1.7f;
        }

        void BuildFlowerBed(Vector3 center, float radius, int count, bool grandmas)
        {
            var bed = Shape.Node(grandmas ? "Бабкина клумба" : "Клумба", transform, center);
            Shape.Make(PrimitiveType.Cylinder, bed, new Vector3(0f, 0.03f, 0f), new Vector3(radius * 2f, 0.03f, radius * 2f),
                new Color(0.42f, 0.30f, 0.20f), false, "Земля клумбы");

            if (grandmas)
            {
                // Бортик из кирпичей
                for (int i = 0; i < 14; i++)
                {
                    float a = i / 14f * Mathf.PI * 2f;
                    Shape.Make(PrimitiveType.Cube, bed, new Vector3(Mathf.Cos(a) * radius, 0.1f, Mathf.Sin(a) * radius),
                        new Vector3(0.5f, 0.2f, 0.25f), new Color(0.75f, 0.35f, 0.28f), false, "Кирпич",
                        new Vector3(0f, -a * Mathf.Rad2Deg + 90f, 0f));
                }
            }

            for (int i = 0; i < count; i++)
            {
                float a = (float)_rng.NextDouble() * Mathf.PI * 2f;
                float r = Mathf.Sqrt((float)_rng.NextDouble()) * (radius - 0.5f);
                var pos = new Vector3(Mathf.Cos(a) * r, 0f, Mathf.Sin(a) * r);
                BuildFlower(bed, pos, PetalColors[_rng.Next(PetalColors.Length)], grandmas);
            }
        }

        void BuildFlower(Transform parent, Vector3 localPos, Color petal, bool grandmas)
        {
            var root = Shape.Node("Цветок", parent, localPos);
            float h = Rand(0.6f, 0.9f);
            var petals = new List<Renderer>();
            Transform head;

            if (_art != null && _art.flower != null)
            {
                Shape.PlaceModel(_art.flower, root, Vector3.zero, Rand(0f, 360f), false);
                head = Shape.Node("Голова", root, new Vector3(0f, h, 0f));
            }
            else
            {
                Shape.Make(PrimitiveType.Cylinder, root, new Vector3(0f, h / 2f, 0f), new Vector3(0.05f, h / 2f, 0.05f),
                    Palette.Leaf, false, "Стебель");
                Shape.Make(PrimitiveType.Sphere, root, new Vector3(0.08f, h * 0.45f, 0f), new Vector3(0.18f, 0.03f, 0.08f),
                    Palette.Leaf, false, "Листок", new Vector3(0f, 0f, 25f));

                head = Shape.Node("Голова", root, new Vector3(0f, h, 0f));
                Shape.Make(PrimitiveType.Sphere, head, Vector3.zero, new Vector3(0.16f, 0.1f, 0.16f),
                    new Color(1f, 0.8f, 0.2f), false, "Серединка");
                for (int p = 0; p < 6; p++)
                {
                    float a = p * 60f;
                    var dir = Quaternion.Euler(0f, a, 0f) * Vector3.forward;
                    var go = Shape.Make(PrimitiveType.Sphere, head, dir * 0.14f, new Vector3(0.12f, 0.04f, 0.2f), petal,
                        false, "Лепесток", new Vector3(-12f, a, 0f));
                    petals.Add(go.GetComponent<Renderer>());
                }
            }

            var flower = root.gameObject.AddComponent<Flower>();
            flower.Init(head, petals, grandmas);
            flower.Prepare(true, false);
            _flowers.Add(flower);
        }

        // ── Постройки ──────────────────────────────────────────

        void BuildHouse(Vector3 pos)
        {
            var root = Shape.Node("Дом", transform, pos);
            if (_art != null && _art.house != null)
            {
                Shape.PlaceModel(_art.house, root, Vector3.zero, 180f);
                return;
            }

            Shape.Make(PrimitiveType.Cube, root, new Vector3(0f, 2.5f, 0f), new Vector3(10f, 5f, 8f), Palette.Wall, true, "Стены");
            Shape.Make(PrimitiveType.Cube, root, new Vector3(0f, 5f, 0f), new Vector3(10.6f, 5.8f, 5.8f), Palette.Roof, true,
                "Крыша", new Vector3(45f, 0f, 0f));
            Shape.Make(PrimitiveType.Cube, root, new Vector3(2.5f, 1.1f, -4.02f), new Vector3(1.2f, 2.2f, 0.06f),
                Palette.Wood, false, "Дверь");
            foreach (float x in new[] { -3f, -0.5f })
            {
                Shape.Make(PrimitiveType.Cube, root, new Vector3(x, 2.4f, -4.03f), new Vector3(1.5f, 1.3f, 0.06f),
                    Palette.Glass, false, "Окно");
                Shape.Make(PrimitiveType.Cube, root, new Vector3(x, 2.4f, -4.06f), new Vector3(0.08f, 1.3f, 0.04f),
                    Palette.White, false, "Рама");
                Shape.Make(PrimitiveType.Cube, root, new Vector3(x, 1.68f, -4.15f), new Vector3(1.7f, 0.1f, 0.3f),
                    Palette.White, false, "Подоконник");
            }
            Shape.Make(PrimitiveType.Cube, root, new Vector3(3f, 7.2f, 1.5f), new Vector3(0.7f, 2f, 0.7f),
                new Color(0.6f, 0.3f, 0.25f), true, "Труба");
        }

        void BuildGreenhouse(Vector3 pos)
        {
            var root = Shape.Node("Теплица", transform, pos);
            if (_art != null && _art.greenhouse != null)
            {
                Shape.PlaceModel(_art.greenhouse, root, Vector3.zero, 0f);
                return;
            }

            const float w = 6f, d = 4f, h = 3f;
            var bouncy = Compat.Bouncy(0.8f);
            void Pane(Vector3 c, Vector3 s, Vector3 euler)
            {
                var go = Shape.Make(PrimitiveType.Cube, root, c, s, Palette.Glass, true, "Стекло", euler);
                go.GetComponent<Collider>().material = bouncy;
            }
            Pane(new Vector3(0f, h / 2f, -d / 2f), new Vector3(w, h, 0.05f), Vector3.zero);
            Pane(new Vector3(0f, h / 2f, d / 2f), new Vector3(w, h, 0.05f), Vector3.zero);
            Pane(new Vector3(-w / 2f, h / 2f, 0f), new Vector3(0.05f, h, d), Vector3.zero);
            Pane(new Vector3(w / 2f, h / 2f, 0f), new Vector3(0.05f, h, d), Vector3.zero);
            Pane(new Vector3(0f, h + 0.55f, -d / 4f), new Vector3(w, 0.05f, d / 2f + 0.3f), new Vector3(-28f, 0f, 0f));
            Pane(new Vector3(0f, h + 0.55f, d / 4f), new Vector3(w, 0.05f, d / 2f + 0.3f), new Vector3(28f, 0f, 0f));

            foreach (float x in new[] { -w / 2f, 0f, w / 2f })
            foreach (float z in new[] { -d / 2f, d / 2f })
                Shape.Make(PrimitiveType.Cube, root, new Vector3(x, h / 2f, z), new Vector3(0.08f, h, 0.08f), Palette.Metal);

            // Помидоры внутри
            for (int i = 0; i < 6; i++)
            {
                var p = new Vector3(-2.2f + i * 0.9f, 0.6f, 0f);
                Shape.Make(PrimitiveType.Cylinder, root, p, new Vector3(0.05f, 0.6f, 0.05f), Palette.Leaf);
                Shape.Make(PrimitiveType.Sphere, root, p + new Vector3(0.1f, 0.3f, 0f), Vector3.one * 0.18f, Palette.Red);
            }
        }

        void BuildJamTable(Vector3 pos)
        {
            var root = Shape.Node("Стол с вареньем", transform, pos);
            if (_art != null && _art.table != null) Shape.PlaceModel(_art.table, root, Vector3.zero);
            else
            {
                Shape.Make(PrimitiveType.Cube, root, new Vector3(0f, 0.8f, 0f), new Vector3(1.8f, 0.08f, 1.1f), Palette.Wood, true, "Столешница");
                foreach (var lp in new[] { new Vector3(-0.8f, 0.4f, -0.45f), new Vector3(0.8f, 0.4f, -0.45f),
                             new Vector3(-0.8f, 0.4f, 0.45f), new Vector3(0.8f, 0.4f, 0.45f) })
                    Shape.Make(PrimitiveType.Cube, root, lp, new Vector3(0.08f, 0.8f, 0.08f), Palette.Wood, true, "Ножка");
                Shape.Make(PrimitiveType.Cube, root, new Vector3(0f, 0.845f, 0f), new Vector3(1.6f, 0.01f, 0.9f),
                    new Color(0.95f, 0.95f, 1f), false, "Скатерть");
            }

            var jar = Shape.Node("Банка", root, new Vector3(0.2f, 0.85f, 0f));
            if (_art != null && _art.jamJar != null) Shape.PlaceModel(_art.jamJar, jar, Vector3.zero);
            else
            {
                Shape.Make(PrimitiveType.Cylinder, jar, new Vector3(0f, 0.18f, 0f), new Vector3(0.32f, 0.18f, 0.32f), Palette.Jam, true, "Варенье");
                Shape.Make(PrimitiveType.Cylinder, jar, new Vector3(0f, 0.38f, 0f), new Vector3(0.34f, 0.03f, 0.34f),
                    new Color(0.9f, 0.85f, 0.75f), false, "Крышка в клетку");
                Shape.Make(PrimitiveType.Cube, jar, new Vector3(-0.55f, 0.02f, 0.1f), new Vector3(0.05f, 0.02f, 0.3f), Palette.Metal, false, "Ложка");
            }

            var zone = Shape.Node("Липкая зона", root, new Vector3(0.2f, 1.4f, 0f));
            var sphere = zone.gameObject.AddComponent<SphereCollider>();
            sphere.isTrigger = true;
            sphere.radius = 1.3f;
            zone.gameObject.AddComponent<JamZone>();
        }

        void BuildFan(Vector3 pos)
        {
            var root = Shape.Node("Вентилятор соседа", transform, pos);
            root.localRotation = Quaternion.Euler(0f, 90f, 0f); // дует вдоль +X

            if (_art != null && _art.fan != null) Shape.PlaceModel(_art.fan, root, Vector3.zero);
            else
            {
                Shape.Make(PrimitiveType.Cylinder, root, new Vector3(0f, 0.04f, 0f), new Vector3(0.6f, 0.04f, 0.6f), Palette.White, true, "Подставка");
                Shape.Make(PrimitiveType.Cylinder, root, new Vector3(0f, 0.9f, 0f), new Vector3(0.06f, 0.9f, 0.06f), Palette.Metal, true, "Стойка");
                Shape.Make(PrimitiveType.Sphere, root, new Vector3(0f, 1.85f, -0.1f), new Vector3(0.35f, 0.35f, 0.4f), Palette.White, true, "Мотор");
                var blades = Shape.Node("Лопасти", root, new Vector3(0f, 1.85f, 0.15f));
                for (int i = 0; i < 3; i++)
                    Shape.Make(PrimitiveType.Cube, blades, Quaternion.Euler(0f, 0f, i * 120f) * new Vector3(0f, 0.32f, 0f),
                        new Vector3(0.18f, 0.6f, 0.02f), new Color(0.55f, 0.75f, 0.95f), false, "Лопасть",
                        new Vector3(0f, 12f, i * 120f));
                blades.gameObject.AddComponent<Spinner>();
            }

            var zone = Shape.Node("Поток воздуха", root, new Vector3(0f, 1.9f, 0f));
            var box = zone.gameObject.AddComponent<BoxCollider>();
            box.isTrigger = true;
            box.center = new Vector3(0f, 0f, 4.5f);
            box.size = new Vector3(2.6f, 3.2f, 9f);
            zone.gameObject.AddComponent<FanZone>();
        }

        void BuildTrashCan(Vector3 pos, int wasps)
        {
            var root = Shape.Node("Мусорка", transform, pos);
            if (_art != null && _art.trashCan != null) Shape.PlaceModel(_art.trashCan, root, Vector3.zero);
            else
            {
                Shape.Make(PrimitiveType.Cylinder, root, new Vector3(0f, 0.6f, 0f), new Vector3(0.9f, 0.6f, 0.9f),
                    new Color(0.25f, 0.45f, 0.3f), true, "Бак");
                Shape.Make(PrimitiveType.Cylinder, root, new Vector3(0.1f, 1.25f, 0f), new Vector3(0.95f, 0.05f, 0.95f),
                    new Color(0.2f, 0.38f, 0.25f), false, "Крышка", new Vector3(0f, 0f, 12f));
                Shape.Make(PrimitiveType.Cube, root, new Vector3(0.7f, 0.08f, 0.4f), new Vector3(0.4f, 0.16f, 0.3f),
                    new Color(0.85f, 0.85f, 0.8f), false, "Пакет");
            }

            for (int i = 0; i < wasps; i++)
            {
                var home = pos + new Vector3(i * 1.2f - 0.6f, 2.6f, 0f);
                _wasps.Add(Wasp.Spawn(transform, home));
            }
        }

        void BuildClothesline(Vector3 a, Vector3 b)
        {
            var root = Shape.Node("Бельё", transform, Vector3.zero);
            Shape.Make(PrimitiveType.Cylinder, root, a + Vector3.up * 1.4f, new Vector3(0.1f, 1.4f, 0.1f), Palette.Wood, true, "Столб");
            Shape.Make(PrimitiveType.Cylinder, root, b + Vector3.up * 1.4f, new Vector3(0.1f, 1.4f, 0.1f), Palette.Wood, true, "Столб");
            Vector3 mid = (a + b) / 2f + Vector3.up * 2.6f;
            float len = Vector3.Distance(a, b);
            Shape.Make(PrimitiveType.Cylinder, root, mid, new Vector3(0.02f, len / 2f, 0.02f), Palette.White, false, "Верёвка",
                new Vector3(0f, 0f, 90f));

            Color[] sheets = { Palette.White, new Color(0.7f, 0.85f, 1f), new Color(1f, 0.75f, 0.8f) };
            for (int i = 0; i < 3; i++)
            {
                Vector3 p = Vector3.Lerp(a, b, (i + 1) / 4f) + Vector3.up * 2.6f;
                var hinge = Shape.Node("Простыня", root, p);
                Shape.Make(PrimitiveType.Cube, hinge, new Vector3(0f, -0.75f, 0f), new Vector3(2.4f, 1.5f, 0.04f),
                    sheets[i], true, "Ткань");
                hinge.gameObject.AddComponent<Sway>();
            }
        }

        void BuildTree(Vector3 pos)
        {
            var root = Shape.Node("Дерево", transform, pos);
            float yaw = Rand(0f, 360f);
            if (_art != null && _art.tree != null)
            {
                Shape.PlaceModel(_art.tree, root, Vector3.zero, yaw);
                return;
            }
            float s = Rand(0.85f, 1.25f);
            Shape.Make(PrimitiveType.Cylinder, root, new Vector3(0f, 1.2f * s, 0f), new Vector3(0.45f, 1.2f * s, 0.45f),
                Palette.Trunk, true, "Ствол");
            Shape.Make(PrimitiveType.Sphere, root, new Vector3(0f, 3.6f * s, 0f), new Vector3(3.2f, 2.6f, 3.2f) * s,
                Palette.Leaf, true, "Крона");
            Shape.Make(PrimitiveType.Sphere, root, new Vector3(0.9f, 4.3f * s, 0.4f), new Vector3(2f, 1.8f, 2f) * s,
                new Color(0.3f, 0.62f, 0.26f), false, "Крона");
            Shape.Make(PrimitiveType.Sphere, root, new Vector3(-0.8f, 4.1f * s, -0.5f), new Vector3(1.8f, 1.6f, 1.8f) * s,
                new Color(0.22f, 0.5f, 0.2f), false, "Крона");
        }

        // ── Вылет ──────────────────────────────────────────────

        /// <summary>Перед вылетом: где сегодня цветёт, где бабкин цветок, осы по местам.</summary>
        public void PrepareSortie()
        {
            var grandmas = new List<Flower>();
            foreach (var f in _flowers)
            {
                f.Prepare(Random.value < 0.75f, false);
                if (f.GrandmasBed) grandmas.Add(f);
            }
            if (grandmas.Count > 0) grandmas[Random.Range(0, grandmas.Count)].Prepare(true, true);

            foreach (var w in _wasps) w.ResetToHome();
            ClearDynamic();

            Wind = Vector3.zero;
            _gustEnd = 0f;
            _nextGust = Time.time + Random.Range(10f, 16f);
        }

        public void EndSortie()
        {
            ClearDynamic();
            Wind = Vector3.zero;
            foreach (var w in _wasps) w.ResetToHome();
        }

        public void AngerBees()
        {
            if (_swarm != null) _swarm.Angry = true;
        }

        void ClearDynamic()
        {
            for (int i = Dynamic.childCount - 1; i >= 0; i--) Destroy(Dynamic.GetChild(i).gameObject);
        }

        public Flower NearestFlower(Vector3 pos, float maxHorizontal)
        {
            Flower best = null;
            float bestSq = maxHorizontal * maxHorizontal;
            foreach (var f in _flowers)
            {
                if (!f.HasPollen) continue;
                Vector3 d = f.HeadPos - pos;
                d.y = 0f;
                float sq = d.sqrMagnitude;
                if (sq < bestSq)
                {
                    bestSq = sq;
                    best = f;
                }
            }
            return best;
        }

        void Update()
        {
            var flow = GameFlow.I;
            if (flow == null || flow.Current != GameFlow.State.Sortie)
            {
                Wind = Vector3.zero;
                return;
            }

            // Порывы ветра: плавно нарастают и стихают
            if (Time.time >= _nextGust && Time.time > _gustEnd)
            {
                _gustStart = Time.time;
                _gustEnd = Time.time + Random.Range(2f, 3.5f);
                _nextGust = _gustEnd + Random.Range(8f, 14f);
                Vector2 d = Random.insideUnitCircle.normalized;
                _gustDir = new Vector3(d.x, 0f, d.y);
                flow.Say(Lines.Pick(Lines.Wind), 2f);
            }

            if (Time.time < _gustEnd)
            {
                float k = Mathf.InverseLerp(_gustStart, _gustEnd, Time.time);
                Wind = _gustDir * (Mathf.Sin(k * Mathf.PI) * 6f);
            }
            else Wind = Vector3.zero;
        }

        float Rand(float min, float max) => min + (float)_rng.NextDouble() * (max - min);
    }
}
