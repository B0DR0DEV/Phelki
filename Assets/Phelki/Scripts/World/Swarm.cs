using System.Collections.Generic;
using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Рой пчёл вокруг улья для живого меню. Если игрок ответил «Нет»,
    /// все пчёлы разворачиваются и зависают прямо перед камерой.
    /// </summary>
    public class Swarm : MonoBehaviour
    {
        class Member
        {
            public Transform t;
            public float phase, radius, height, speed;
            public Vector3 angryOffset;
        }

        readonly List<Member> _members = new List<Member>();
        Vector3 _center;
        bool _angry;

        public static Swarm Build(Transform parent, Vector3 center, int count)
        {
            var root = new GameObject("Рой");
            root.transform.SetParent(parent, false);
            var swarm = root.AddComponent<Swarm>();
            swarm._center = center;

            var art = PhelkiArtSet.Current;
            for (int i = 0; i < count; i++)
            {
                var t = Shape.Node("Пчела роя", root.transform, center);
                t.localScale = Vector3.one * Random.Range(0.45f, 0.6f);
                if (art != null && art.bee != null) Shape.PlaceModel(art.bee, t, Vector3.zero, 0f, false);
                else BeeVisual.BuildPlaceholder(t, false);
                t.gameObject.AddComponent<WingFlap>().speed = Random.Range(45f, 60f);

                swarm._members.Add(new Member
                {
                    t = t,
                    phase = Random.value * Mathf.PI * 2f,
                    radius = Random.Range(1.6f, 3.8f),
                    height = Random.Range(1.4f, 3.2f),
                    speed = Random.Range(0.5f, 1.1f) * (Random.value > 0.5f ? 1f : -1f),
                    angryOffset = new Vector3(Random.Range(-1.6f, 1.6f), Random.Range(-1.2f, 1.2f), Random.Range(-0.4f, 0.6f))
                });
            }
            return swarm;
        }

        public bool Angry
        {
            get => _angry;
            set => _angry = value;
        }

        void Update()
        {
            var cam = Camera.main;
            bool angry = _angry && cam != null && PlayerProfile.Current.Side == Side.Human &&
                         GameFlow.I != null && GameFlow.I.Current != GameFlow.State.Sortie;

            foreach (var m in _members)
            {
                Vector3 target;
                Quaternion look;
                if (angry)
                {
                    target = cam.transform.position + cam.transform.forward * 4.5f +
                             cam.transform.right * m.angryOffset.x + cam.transform.up * m.angryOffset.y +
                             cam.transform.forward * m.angryOffset.z;
                    target += new Vector3(0f, Mathf.Sin(Time.time * 7f + m.phase) * 0.08f, 0f);
                    look = Quaternion.LookRotation(cam.transform.position - m.t.position);
                    m.t.position = Vector3.Lerp(m.t.position, target, 3f * Time.deltaTime);
                }
                else
                {
                    float a = Time.time * m.speed + m.phase;
                    target = _center + new Vector3(Mathf.Cos(a) * m.radius,
                        m.height + Mathf.Sin(Time.time * 2f + m.phase) * 0.2f, Mathf.Sin(a) * m.radius);
                    Vector3 tangent = new Vector3(-Mathf.Sin(a), 0f, Mathf.Cos(a)) * Mathf.Sign(m.speed);
                    look = Quaternion.LookRotation(tangent);
                    m.t.position = Vector3.Lerp(m.t.position, target, 4f * Time.deltaTime);
                }
                m.t.rotation = Quaternion.Slerp(m.t.rotation, look, 6f * Time.deltaTime);
            }
        }
    }
}
