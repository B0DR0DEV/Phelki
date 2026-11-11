using UnityEngine;

namespace Phelki
{
    /// <summary>Банка варенья: прилипаешь на пару секунд, зато +3 сладкой пыльцы.</summary>
    public class JamZone : MonoBehaviour
    {
        float _readyAt;

        void OnTriggerEnter(Collider other)
        {
            var flow = GameFlow.I;
            if (flow == null || flow.Current != GameFlow.State.Sortie || Time.time < _readyAt) return;
            var bee = other.GetComponentInParent<BeeController>();
            if (bee == null) return;

            _readyAt = Time.time + 6f;
            bee.Stick(2.2f);
            bee.AddPollen(3, true);
            flow.Say(Lines.Pick(Lines.Jam));
            flow.Toast("Прилипла! +3 сладкой пыльцы");
        }
    }
}
