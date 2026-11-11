using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Улей игрока. Влетела пчела с пыльцой — пыльца превращается в мёд.
    /// Большая доставка (20+) даёт бонус.
    /// </summary>
    public class Hive : MonoBehaviour
    {
        public const int BigDelivery = 20;
        public const int BigBonus = 5;

        Transform _body;
        float _pulse;
        Vector3 _bodyScale;

        public void Init(Transform body)
        {
            _body = body;
            _bodyScale = body.localScale;
        }

        void OnTriggerEnter(Collider other) => TryDeliver(other);
        void OnTriggerStay(Collider other) => TryDeliver(other);

        void TryDeliver(Collider other)
        {
            var flow = GameFlow.I;
            if (flow == null || flow.Current != GameFlow.State.Sortie) return;

            var bee = other.GetComponentInParent<BeeController>();
            if (bee == null || bee.Pollen <= 0) return;

            int pollen = bee.TakeAllPollen();
            bool big = pollen >= BigDelivery;
            int honey = pollen + (big ? BigBonus : 0);

            flow.Stats.honeyMade += honey;
            flow.Stats.deposits++;
            flow.Toast(big ? $"+{honey} мёда · бонус деда!" : $"+{honey} мёда");
            flow.Say(Lines.Pick(big ? Lines.BigDeposit : Lines.Deposit));
            _pulse = 1f;
        }

        void Update()
        {
            if (_body == null || _pulse <= 0f) return;
            _pulse = Mathf.MoveTowards(_pulse, 0f, Time.deltaTime * 2.5f);
            float k = 1f + Mathf.Sin(_pulse * Mathf.PI) * 0.12f;
            _body.localScale = _bodyScale * k;
        }
    }
}
