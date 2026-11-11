using System.Collections.Generic;
using UnityEngine;

namespace Phelki
{
    public class EscapeStats
    {
        public int jars;
        public int jarsNeeded = 3;
        public int stings;
        public int swats;
        public int smokes;
        public int dodges;
        public float time;
        public bool escaped;

        /// <summary>"escaped", "ambulance" или "timeout".</summary>
        public string ending = "";
    }

    /// <summary>
    /// Матч «Побег» за людей против пчёл-ботов (часть 1, офлайн).
    /// Цель: утащить 3 банки мёда, добежать до машины и продержаться
    /// у двери, пока она заводится. Пчёлы жалят — отёк растёт.
    /// В части 3 боты заменятся живыми игроками-пчёлами по сети.
    /// </summary>
    public class EscapeMatch : MonoBehaviour
    {
        public const float Length = 180f;
        public const float CarStartSeconds = 3.5f;
        public const float CarRadius = 2.6f;
        public const int BotCount = 12;

        public HumanController Human { get; private set; }
        public readonly List<BeeBot> Bots = new List<BeeBot>();
        public EscapeStats Stats { get; private set; }
        public float TimeLeft { get; private set; }
        public float CarProgress { get; private set; }
        public bool AllJars => Stats.jars >= Stats.jarsNeeded;
        public bool Ending => _endAt > 0f;

        World _world;
        readonly List<HoneyJar> _jars = new List<HoneyJar>();
        float _endAt, _stingSayAt;
        bool _carSaid;

        public static EscapeMatch Begin(World world, Transform parent)
        {
            var go = new GameObject("Побег");
            go.transform.SetParent(parent, false);
            var m = go.AddComponent<EscapeMatch>();
            m.Setup(world);
            return m;
        }

        void Setup(World world)
        {
            _world = world;
            Stats = new EscapeStats();
            TimeLeft = Length;

            Human = HumanController.Spawn(transform, world.EscapeSpawn.position, 0f);

            // Банки — в 3 случайных местах из списка
            var spots = new List<Vector3>(world.JarSpots);
            for (int i = spots.Count - 1; i > 0; i--)
            {
                int j = Random.Range(0, i + 1);
                (spots[i], spots[j]) = (spots[j], spots[i]);
            }
            for (int i = 0; i < Stats.jarsNeeded && i < spots.Count; i++)
                _jars.Add(HoneyJar.Spawn(transform, spots[i]));
            Stats.jarsNeeded = _jars.Count;

            // Рой вылетает из улья не сразу — у дачника есть пара секунд форы
            for (int i = 0; i < BotCount; i++)
            {
                float angle = i * 360f / BotCount;
                Vector3 pos = world.HivePosition + Quaternion.Euler(0f, angle, 0f) * Vector3.forward * 2f + Vector3.up * 2f;
                var bot = BeeBot.Spawn(transform, pos, angle, Random.Range(2f, 5f));
                Bots.Add(bot);
                Physics.IgnoreCollision(bot.Body, Human.Body);
            }
        }

        void Update()
        {
            float dt = Time.deltaTime;
            var flow = GameFlow.I;
            if (flow == null) return;

            if (Ending)
            {
                if (Stats.escaped) _world.DriveCar(dt);
                if (Time.time >= _endAt) flow.EndEscape();
                return;
            }

            TimeLeft -= dt;
            Stats.time += dt;
            if (TimeLeft <= 0f)
            {
                Finish("timeout");
                return;
            }

            // Машина: стоишь у двери со всеми банками — заводится
            bool atCar = false;
            if (AllJars)
            {
                Vector3 d = Human.transform.position - _world.CarDoor.position;
                d.y = 0f;
                atCar = d.magnitude < CarRadius;
            }

            if (atCar)
            {
                if (!_carSaid)
                {
                    _carSaid = true;
                    flow.Say(Lines.Pick(Lines.CarStarting));
                }
                CarProgress = Mathf.MoveTowards(CarProgress, 1f, dt / CarStartSeconds);
                if (CarProgress >= 1f) Finish("escaped");
            }
            else
            {
                CarProgress = Mathf.MoveTowards(CarProgress, 0f, dt * 0.5f);
            }
        }

        public void OnStung(HumanController human)
        {
            if (Ending) return;
            Stats.stings++;
            if (Time.time > _stingSayAt && Random.value < 0.4f)
            {
                _stingSayAt = Time.time + 4f;
                GameFlow.I.Say(Lines.Pick(Lines.Stung), 2f);
            }
            if (human.Swelling >= 1f) Finish("ambulance");
        }

        public void OnJarTaken(HoneyJar jar)
        {
            if (Ending) return;
            _jars.Remove(jar);
            Stats.jars++;
            GameFlow.I.Toast($"Банка {Stats.jars}/{Stats.jarsNeeded}");
            GameFlow.I.Say(Lines.Pick(AllJars ? Lines.AllJars : Lines.JarTaken));
        }

        /// <summary>Куда бежать: ближайшая банка, а когда все собраны — к машине.</summary>
        public bool TryGetTarget(out Vector3 position, out string label)
        {
            position = default;
            label = "";
            if (Human == null) return false;

            if (AllJars)
            {
                position = _world.CarDoor.position;
                label = "Машина";
                return true;
            }

            float best = float.MaxValue;
            bool found = false;
            foreach (var j in _jars)
            {
                if (j == null) continue;
                float d = (j.transform.position - Human.transform.position).sqrMagnitude;
                if (d < best)
                {
                    best = d;
                    position = j.transform.position;
                    found = true;
                }
            }
            label = "Банка";
            return found;
        }

        void Finish(string ending)
        {
            if (Ending) return;
            Stats.ending = ending;
            Stats.escaped = ending == "escaped";
            Human.Frozen = true;

            var flow = GameFlow.I;
            switch (ending)
            {
                case "escaped":
                    Human.gameObject.SetActive(false); // сел в машину
                    flow.Say(Lines.Pick(Lines.Escaped), 3f);
                    _endAt = Time.time + 2.4f;
                    break;
                case "ambulance":
                    var visual = Human.GetComponentInChildren<HumanVisual>();
                    if (visual != null) visual.Faint();
                    flow.Say(Lines.Pick(Lines.Ambulance), 3f);
                    _endAt = Time.time + 2f;
                    break;
                default:
                    flow.Say(Lines.Pick(Lines.EscapeTimeout), 3f);
                    _endAt = Time.time + 1.5f;
                    break;
            }
        }
    }
}
