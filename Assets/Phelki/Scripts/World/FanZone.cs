using UnityEngine;

namespace Phelki
{
    /// <summary>Соседский вентилятор: сдувает пчелу вдоль своей оси Z.</summary>
    public class FanZone : MonoBehaviour
    {
        public float strength = 16f;
        float _saidAt = -100f;

        void OnTriggerStay(Collider other)
        {
            var flow = GameFlow.I;
            if (flow == null || flow.Current != GameFlow.State.Sortie) return;
            var bee = other.GetComponentInParent<BeeController>();
            if (bee == null) return;

            bee.Push(transform.forward * strength);
            if (Time.time - _saidAt > 12f)
            {
                _saidAt = Time.time;
                flow.Say(Lines.Pick(Lines.Fan));
            }
        }
    }
}
