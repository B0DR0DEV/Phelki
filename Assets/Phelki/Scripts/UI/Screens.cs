using UnityEngine;
using UnityEngine.UI;

namespace Phelki
{
    /// <summary>
    /// Все экраны игры: вопрос деда, пасека (меню), вылет (HUD), итоги.
    /// Поверх экранов — реплики деда и всплывающие сообщения.
    /// </summary>
    public class Screens : MonoBehaviour
    {
        RectTransform _safe, _screen;

        RectTransform _say;
        Text _sayText;
        CanvasGroup _sayGroup;
        float _sayUntil;

        RectTransform _toast;
        Text _toastText;
        CanvasGroup _toastGroup;
        float _toastAt = -100f;

        bool _questionActive;
        float _questionAt;
        int _silence;

        Button _changeBtn;
        Text _changeLabel;

        bool _hudActive;
        Text _pollenText, _timerText, _honeyText, _hiveText;
        RectTransform _pollenFill, _arrow;
        CanvasGroup _hintGroup;
        float _hintAt;

        bool _escapeHudActive;
        Text _jarsText, _swellText, _targetText, _swatLabel, _smokeLabel;
        RectTransform _swellFill, _carFill, _targetArrow;
        CanvasGroup _carGroup;
        Button _swatBtn, _smokeBtn;

        static readonly Color SoftWhite = new Color(1f, 1f, 1f, 0.85f);
        static readonly Color CardBg = new Color(1f, 0.98f, 0.93f, 0.97f);
        static readonly Color DeepHoney = new Color(0.85f, 0.52f, 0.04f);

        public static Screens Create()
        {
            UiKit.EnsureEventSystem();

            var go = new GameObject("Интерфейс", typeof(RectTransform));
            var canvas = go.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 10;
            var scaler = go.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1080f, 1920f);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0.35f;
            go.AddComponent<GraphicRaycaster>();

            var s = go.AddComponent<Screens>();
            s.BuildShell();
            return s;
        }

        void BuildShell()
        {
            _safe = UiKit.Area("Безопасная зона", transform, Vector2.zero, Vector2.one);
            _safe.gameObject.AddComponent<SafeArea>();

            // Реплика деда
            var say = UiKit.Panel(_safe, "Дед говорит", new Vector2(0.05f, 0.5f), new Vector2(0.95f, 0.59f), CardBg);
            _say = say.rectTransform;
            _sayGroup = say.gameObject.AddComponent<CanvasGroup>();
            _sayGroup.alpha = 0f;
            _sayGroup.blocksRaycasts = false;
            UiKit.Label(say.transform, "ДЕД-ПАСЕЧНИК", 28, new Vector2(0.04f, 0.64f), new Vector2(0.7f, 0.94f),
                TextAnchor.UpperLeft, DeepHoney, FontStyle.Bold, false);
            _sayText = UiKit.Label(say.transform, "", 44, new Vector2(0.04f, 0.06f), new Vector2(0.96f, 0.68f),
                TextAnchor.MiddleLeft, UiKit.Ink, FontStyle.Normal, false);

            // Всплывающее сообщение (+мёд и т.п.)
            _toastText = UiKit.Label(_safe, "", 60, new Vector2(0.06f, 0.6f), new Vector2(0.94f, 0.66f),
                TextAnchor.MiddleCenter, UiKit.HoneyBg, FontStyle.Bold);
            _toast = _toastText.rectTransform;
            _toastGroup = _toastText.gameObject.AddComponent<CanvasGroup>();
            _toastGroup.alpha = 0f;
            _toastGroup.blocksRaycasts = false;
        }

        RectTransform NewScreen(string name)
        {
            if (_screen != null) Destroy(_screen.gameObject);
            _screen = UiKit.Area(name, _safe, Vector2.zero, Vector2.one);
            _screen.SetSiblingIndex(0); // под репликой деда и всплывашками
            _questionActive = false;
            _hudActive = false;
            _escapeHudActive = false;
            _changeBtn = null;
            _changeLabel = null;
            return _screen;
        }

        void PlaceSay(float yMin, float yMax)
        {
            _say.anchorMin = new Vector2(0.05f, yMin);
            _say.anchorMax = new Vector2(0.95f, yMax);
        }

        // ── Вопрос ─────────────────────────────────────────────

        public void ShowQuestion()
        {
            var s = NewScreen("Вопрос");
            PlaceSay(0.5f, 0.59f);

            UiKit.Panel(s, "Затемнение", Vector2.zero, new Vector2(1f, 0.46f), UiKit.Shade, false);
            UiKit.Label(s, "Дед-пасечник смотрит на тебя очень внимательно", 40,
                new Vector2(0.08f, 0.37f), new Vector2(0.92f, 0.43f), TextAnchor.MiddleCenter, SoftWhite);
            UiKit.Label(s, "Ты пчёлок уважаешь?", 96, new Vector2(0.04f, 0.24f), new Vector2(0.96f, 0.37f),
                TextAnchor.MiddleCenter, UiKit.HoneyBg, FontStyle.Bold);

            UiKit.MakeButton(s, "Уважаю", new Vector2(0.07f, 0.07f), new Vector2(0.48f, 0.19f), UiKit.HoneyBg, UiKit.Ink,
                () => GameFlow.I.Answer(Side.Bee), 64);
            UiKit.MakeButton(s, "Нет", new Vector2(0.52f, 0.07f), new Vector2(0.93f, 0.19f), UiKit.DangerBg, Color.white,
                () => GameFlow.I.Answer(Side.Human), 64);

            UiKit.Label(s, "Ответ останется с тобой. Передумать можно один раз в первые 10 минут.", 30,
                new Vector2(0.06f, 0.012f), new Vector2(0.94f, 0.06f), TextAnchor.MiddleCenter,
                new Color(1f, 1f, 1f, 0.6f));

            _questionActive = true;
            _questionAt = Time.time;
            _silence = 0;
        }

        // ── Пасека (меню) ──────────────────────────────────────

        public void ShowHub()
        {
            var p = PlayerProfile.Current;
            bool bee = p.Side == Side.Bee;
            var s = NewScreen("Пасека");
            PlaceSay(0.4f, 0.49f);

            var top = UiKit.Panel(s, "Верх", new Vector2(0.04f, 0.905f), new Vector2(0.96f, 0.975f), UiKit.Shade);
            if (bee)
            {
                UiKit.Label(top.transform, $"Мёд: {p.honey}", 46, new Vector2(0.05f, 0f), new Vector2(0.5f, 1f),
                    TextAnchor.MiddleLeft, UiKit.HoneyBg, FontStyle.Bold);
                UiKit.Label(top.transform, $"Рекорд вылета: {p.bestSortieHoney}", 36, new Vector2(0.5f, 0f),
                    new Vector2(0.95f, 1f), TextAnchor.MiddleRight);
            }
            else
            {
                UiKit.Label(top.transform, "Неуважающий", 46, new Vector2(0.05f, 0f), new Vector2(0.5f, 1f),
                    TextAnchor.MiddleLeft, new Color(1f, 0.58f, 0.52f), FontStyle.Bold);
                string best = p.bestEscapeTime > 0f ? $" · лучший {FormatTime(p.bestEscapeTime)}" : "";
                UiKit.Label(top.transform, $"Побегов: {p.escapeWins}/{p.escapeAttempts}{best}", 34,
                    new Vector2(0.45f, 0f), new Vector2(0.95f, 1f), TextAnchor.MiddleRight);
            }

            UiKit.Label(s, bee ? "Твоя пасека" : "Ты не уважаешь пчёлок", 76, new Vector2(0.04f, 0.82f),
                new Vector2(0.96f, 0.9f), TextAnchor.MiddleCenter, Color.white, FontStyle.Bold);

            UiKit.Panel(s, "Низ", Vector2.zero, new Vector2(1f, 0.37f), UiKit.Shade, false);

            if (bee)
            {
                UiKit.MakeButton(s, "ВЫЛЕТ", new Vector2(0.1f, 0.2f), new Vector2(0.9f, 0.32f), UiKit.HoneyBg, UiKit.Ink,
                    () => GameFlow.I.StartSortie(), 84);
                Soon(s, "Набеги\nскоро", 0.05f, 0.33f);
                Soon(s, "Породы\nскоро", 0.36f, 0.64f);
                Soon(s, "Охота\nскоро", 0.67f, 0.95f);
            }
            else
            {
                UiKit.Label(s, "Утащи 3 банки мёда и уезжай на машине. Пчёлы будут жалить — отбивайся мухобойкой и дымом.",
                    36, new Vector2(0.08f, 0.24f), new Vector2(0.92f, 0.34f), TextAnchor.MiddleCenter);
                UiKit.MakeButton(s, "ПОБЕГ", new Vector2(0.1f, 0.1f), new Vector2(0.9f, 0.22f), UiKit.DangerBg,
                    Color.white, () => GameFlow.I.StartEscape(), 84);
            }

            if (p.CanChangeAnswer)
            {
                _changeBtn = UiKit.MakeButton(s, "", new Vector2(0.18f, 0.012f), new Vector2(0.82f, 0.07f),
                    new Color(1f, 1f, 1f, 0.2f), Color.white,
                    () => GameFlow.I.Answer(bee ? Side.Human : Side.Bee), 34);
                _changeLabel = _changeBtn.GetComponentInChildren<Text>();
            }

            if (Time.time > _sayUntil) Say(Lines.Pick(bee ? Lines.HubBee : Lines.HubHuman), 3f);
        }

        void Soon(Transform parent, string text, float x0, float x1)
        {
            var b = UiKit.MakeButton(parent, text, new Vector2(x0, 0.085f), new Vector2(x1, 0.175f), UiKit.Muted,
                Color.white, null, 38);
            b.interactable = false;
        }

        // ── Вылет (HUD) ────────────────────────────────────────

        public void ShowHud()
        {
            var s = NewScreen("Вылет");
            PlaceSay(0.73f, 0.82f);

            var top = UiKit.Panel(s, "Верх", new Vector2(0.03f, 0.9f), new Vector2(0.97f, 0.975f), UiKit.Shade);
            _pollenText = UiKit.Label(top.transform, "", 38, new Vector2(0.03f, 0.45f), new Vector2(0.36f, 0.95f),
                TextAnchor.MiddleLeft, Color.white, FontStyle.Bold);
            var barBg = UiKit.Panel(top.transform, "Полоса", new Vector2(0.03f, 0.14f), new Vector2(0.36f, 0.38f),
                new Color(1f, 1f, 1f, 0.18f));
            _pollenFill = UiKit.Panel(barBg.transform, "Заполнение", Vector2.zero, new Vector2(0.02f, 1f),
                UiKit.HoneyBg).rectTransform;
            _timerText = UiKit.Label(top.transform, "3:00", 64, new Vector2(0.38f, 0f), new Vector2(0.62f, 1f),
                TextAnchor.MiddleCenter, Color.white, FontStyle.Bold);
            _honeyText = UiKit.Label(top.transform, "", 40, new Vector2(0.64f, 0f), new Vector2(0.97f, 1f),
                TextAnchor.MiddleRight, UiKit.HoneyBg, FontStyle.Bold);

            var hiveTag = UiKit.Panel(s, "К улью", new Vector2(0.03f, 0.845f), new Vector2(0.42f, 0.89f), UiKit.Shade);
            var arrowRt = UiKit.Area("Стрелка", hiveTag.transform, new Vector2(0.03f, 0.12f), new Vector2(0.17f, 0.88f));
            var arrowImg = arrowRt.gameObject.AddComponent<Image>();
            arrowImg.sprite = UiKit.Triangle;
            arrowImg.preserveAspect = true;
            arrowImg.color = UiKit.HoneyBg;
            arrowImg.raycastTarget = false;
            _arrow = arrowRt;
            _hiveText = UiKit.Label(hiveTag.transform, "Улей", 34, new Vector2(0.2f, 0f), new Vector2(0.97f, 1f),
                TextAnchor.MiddleLeft, Color.white, FontStyle.Bold);

            UiKit.MakeButton(s, "Домой", new Vector2(0.72f, 0.845f), new Vector2(0.97f, 0.89f),
                new Color(1f, 1f, 1f, 0.25f), Color.white, () => GameFlow.I.EndSortie(), 34);

            var hint = UiKit.Panel(s, "Подсказка", new Vector2(0.05f, 0.03f), new Vector2(0.95f, 0.15f), UiKit.Shade);
            UiKit.Label(hint.transform,
                "Веди пальцем — пчела летит следом.\nЗависни над цветком — соберёшь пыльцу, неси её в улей.\n" +
                "Быстрый свайп — рывок: им можно протаранить осу.", 34,
                new Vector2(0.04f, 0.06f), new Vector2(0.96f, 0.94f));
            _hintGroup = hint.gameObject.AddComponent<CanvasGroup>();
            _hintGroup.blocksRaycasts = false;
            _hintAt = Time.time;

            _hudActive = true;
        }

        // ── Итоги ──────────────────────────────────────────────

        public void ShowResults(SortieStats stats, bool record)
        {
            var p = PlayerProfile.Current;
            var s = NewScreen("Итоги");
            PlaceSay(0.81f, 0.895f);

            UiKit.Panel(s, "Затемнение", Vector2.zero, Vector2.one, new Color(0f, 0f, 0f, 0.45f), false);
            var card = UiKit.Panel(s, "Карточка", new Vector2(0.06f, 0.2f), new Vector2(0.94f, 0.8f), CardBg).transform;

            UiKit.Label(card, "Вылет окончен", 70, new Vector2(0.05f, 0.85f), new Vector2(0.95f, 0.97f),
                TextAnchor.MiddleCenter, UiKit.Ink, FontStyle.Bold, false);
            if (record)
                UiKit.Label(card, "Новый рекорд!", 44, new Vector2(0.05f, 0.77f), new Vector2(0.95f, 0.85f),
                    TextAnchor.MiddleCenter, DeepHoney, FontStyle.Bold, false);
            UiKit.Label(card, $"+{stats.honeyMade} мёда", 92, new Vector2(0.05f, 0.6f), new Vector2(0.95f, 0.77f),
                TextAnchor.MiddleCenter, DeepHoney, FontStyle.Bold, false);

            string body =
                $"Пыльцы собрано: {stats.pollenCollected}\n" +
                $"Доставок в улей: {stats.deposits}\n" +
                $"Рассыпано при ударах: {stats.pollenLost}\n" +
                $"Отжали осы: {stats.pollenStolen}\n" +
                $"Врезалась: {stats.crashes} раз\n" +
                $"Ос протаранено: {stats.waspsRammed}";
            UiKit.Label(card, body, 40, new Vector2(0.08f, 0.27f), new Vector2(0.92f, 0.6f), TextAnchor.MiddleLeft,
                UiKit.Ink, FontStyle.Normal, false);
            UiKit.Label(card, $"На пасеке всего: {p.honey} мёда", 38, new Vector2(0.05f, 0.18f),
                new Vector2(0.95f, 0.27f), TextAnchor.MiddleCenter, UiKit.Ink, FontStyle.Bold, false);

            UiKit.MakeButton(s, "Ещё вылет", new Vector2(0.06f, 0.07f), new Vector2(0.6f, 0.17f), UiKit.HoneyBg,
                UiKit.Ink, () => GameFlow.I.StartSortie(), 60);
            UiKit.MakeButton(s, "На пасеку", new Vector2(0.63f, 0.07f), new Vector2(0.94f, 0.17f), UiKit.Muted,
                Color.white, () => GameFlow.I.ShowHub(), 44);

            Say(Lines.Pick(stats.honeyMade >= 40 ? Lines.ResultGood : Lines.ResultBad), 4f);
        }

        // ── Побег (HUD за людей) ───────────────────────────────

        public void ShowEscapeHud()
        {
            var s = NewScreen("Побег");
            PlaceSay(0.73f, 0.82f);

            var top = UiKit.Panel(s, "Верх", new Vector2(0.03f, 0.9f), new Vector2(0.97f, 0.975f), UiKit.Shade);
            _jarsText = UiKit.Label(top.transform, "", 42, new Vector2(0.03f, 0f), new Vector2(0.34f, 1f),
                TextAnchor.MiddleLeft, UiKit.HoneyBg, FontStyle.Bold);
            _timerText = UiKit.Label(top.transform, "3:00", 64, new Vector2(0.36f, 0f), new Vector2(0.6f, 1f),
                TextAnchor.MiddleCenter, Color.white, FontStyle.Bold);
            _swellText = UiKit.Label(top.transform, "", 34, new Vector2(0.62f, 0.45f), new Vector2(0.97f, 0.95f),
                TextAnchor.MiddleRight, Color.white, FontStyle.Bold);
            var swellBg = UiKit.Panel(top.transform, "Отёк", new Vector2(0.62f, 0.14f), new Vector2(0.97f, 0.38f),
                new Color(1f, 1f, 1f, 0.18f));
            _swellFill = UiKit.Panel(swellBg.transform, "Заполнение", Vector2.zero, new Vector2(0.02f, 1f),
                new Color(0.95f, 0.38f, 0.35f)).rectTransform;

            var targetTag = UiKit.Panel(s, "Цель", new Vector2(0.03f, 0.845f), new Vector2(0.5f, 0.89f), UiKit.Shade);
            var arrowRt = UiKit.Area("Стрелка", targetTag.transform, new Vector2(0.03f, 0.12f), new Vector2(0.15f, 0.88f));
            var arrowImg = arrowRt.gameObject.AddComponent<Image>();
            arrowImg.sprite = UiKit.Triangle;
            arrowImg.preserveAspect = true;
            arrowImg.color = UiKit.HoneyBg;
            arrowImg.raycastTarget = false;
            _targetArrow = arrowRt;
            _targetText = UiKit.Label(targetTag.transform, "", 34, new Vector2(0.18f, 0f), new Vector2(0.97f, 1f),
                TextAnchor.MiddleLeft, Color.white, FontStyle.Bold);

            UiKit.MakeButton(s, "Сдаться", new Vector2(0.72f, 0.845f), new Vector2(0.97f, 0.89f),
                new Color(1f, 1f, 1f, 0.25f), Color.white, () => GameFlow.I.EndEscape(), 34);

            // Полоса «заводим машину»
            var car = UiKit.Panel(s, "Заводим", new Vector2(0.12f, 0.58f), new Vector2(0.88f, 0.66f), UiKit.Shade);
            UiKit.Label(car.transform, "Заводим машину… держись!", 40, new Vector2(0.04f, 0.45f), new Vector2(0.96f, 0.95f),
                TextAnchor.MiddleCenter, Color.white, FontStyle.Bold);
            var carBg = UiKit.Panel(car.transform, "Полоса", new Vector2(0.06f, 0.12f), new Vector2(0.94f, 0.38f),
                new Color(1f, 1f, 1f, 0.18f));
            _carFill = UiKit.Panel(carBg.transform, "Заполнение", Vector2.zero, new Vector2(0.02f, 1f), UiKit.HoneyBg)
                .rectTransform;
            _carGroup = car.gameObject.AddComponent<CanvasGroup>();
            _carGroup.alpha = 0f;
            _carGroup.blocksRaycasts = false;

            // Инструменты
            _smokeBtn = UiKit.MakeButton(s, "Дымарь", new Vector2(0.6f, 0.15f), new Vector2(0.96f, 0.24f),
                new Color(0.45f, 0.55f, 0.65f), Color.white, () =>
                {
                    var h = CurrentHuman();
                    if (h != null) h.Smoke();
                }, 46);
            _smokeLabel = _smokeBtn.GetComponentInChildren<Text>();
            _swatBtn = UiKit.MakeButton(s, "Мухобойка", new Vector2(0.6f, 0.035f), new Vector2(0.96f, 0.14f),
                UiKit.HoneyBg, UiKit.Ink, () =>
                {
                    var h = CurrentHuman();
                    if (h != null) h.Swat();
                }, 50);
            _swatLabel = _swatBtn.GetComponentInChildren<Text>();

            var hint = UiKit.Panel(s, "Подсказка", new Vector2(0.04f, 0.035f), new Vector2(0.57f, 0.24f), UiKit.Shade);
            UiKit.Label(hint.transform,
                "Веди пальцем — бежишь следом.\nСвайп — перекат: пока катишься, не жалят.\n" +
                "Собери банки и стой у машины, пока заводится.", 32,
                new Vector2(0.05f, 0.05f), new Vector2(0.95f, 0.95f));
            _hintGroup = hint.gameObject.AddComponent<CanvasGroup>();
            _hintGroup.blocksRaycasts = false;
            _hintAt = Time.time;

            _escapeHudActive = true;
        }

        void UpdateEscapeHud()
        {
            var flow = GameFlow.I;
            var m = flow != null ? flow.Escape : null;
            if (m == null || m.Human == null) return;
            var h = m.Human;

            _jarsText.text = m.AllJars ? "Все банки — к машине!" : $"Банки {m.Stats.jars}/{m.Stats.jarsNeeded}";
            int secs = Mathf.CeilToInt(Mathf.Max(0f, m.TimeLeft));
            _timerText.text = $"{secs / 60}:{secs % 60:00}";
            _timerText.color = secs <= 20 ? new Color(1f, 0.55f, 0.5f) : Color.white;

            _swellText.text = $"Отёк {Mathf.RoundToInt(h.Swelling * 100f)}%";
            _swellFill.anchorMax = new Vector2(Mathf.Max(0.02f, h.Swelling), 1f);

            if (m.TryGetTarget(out var target, out var label))
            {
                Vector3 d = target - h.transform.position;
                d.y = 0f;
                _targetText.text = $"{label} · {Mathf.RoundToInt(d.magnitude)} м";
                float camYaw = Camera.main != null ? Camera.main.transform.eulerAngles.y : 0f;
                float angle = Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg - camYaw;
                _targetArrow.localRotation = Quaternion.Euler(0f, 0f, -angle);
            }

            _carGroup.alpha = Mathf.MoveTowards(_carGroup.alpha, m.CarProgress > 0.01f ? 1f : 0f, Time.deltaTime * 6f);
            _carFill.anchorMax = new Vector2(Mathf.Max(0.02f, m.CarProgress), 1f);

            float swatIn = h.SwatReadyIn, smokeIn = h.SmokeReadyIn;
            _swatBtn.interactable = swatIn <= 0f;
            _swatLabel.text = "Мухобойка";
            _smokeBtn.interactable = smokeIn <= 0f;
            _smokeLabel.text = smokeIn > 0f ? $"Дымарь · {Mathf.CeilToInt(smokeIn)}" : "Дымарь";

            float ht = Time.time - _hintAt;
            _hintGroup.alpha = ht < 8f ? 1f : Mathf.Clamp01(1f - (ht - 8f) / 1.5f);
        }

        public void ShowEscapeResults(EscapeStats stats, bool record)
        {
            var p = PlayerProfile.Current;
            var s = NewScreen("Итоги побега");
            PlaceSay(0.81f, 0.895f);

            UiKit.Panel(s, "Затемнение", Vector2.zero, Vector2.one, new Color(0f, 0f, 0f, 0.45f), false);
            var card = UiKit.Panel(s, "Карточка", new Vector2(0.06f, 0.2f), new Vector2(0.94f, 0.8f), CardBg).transform;

            string title, big;
            Color bigColor = DeepHoney;
            switch (stats.ending)
            {
                case "escaped":
                    title = "Ты сбежал!";
                    big = $"за {FormatTime(stats.time)}";
                    break;
                case "ambulance":
                    title = "Увезли на скорой";
                    big = $"{stats.stings} укусов";
                    bigColor = UiKit.DangerBg;
                    break;
                case "timeout":
                    title = "Не успел";
                    big = "стемнело";
                    bigColor = UiKit.Muted;
                    break;
                default:
                    title = "Сдался";
                    big = "пчёлы довольны";
                    bigColor = UiKit.Muted;
                    break;
            }

            UiKit.Label(card, title, 70, new Vector2(0.05f, 0.85f), new Vector2(0.95f, 0.97f),
                TextAnchor.MiddleCenter, UiKit.Ink, FontStyle.Bold, false);
            if (record)
                UiKit.Label(card, "Лучшее время!", 44, new Vector2(0.05f, 0.77f), new Vector2(0.95f, 0.85f),
                    TextAnchor.MiddleCenter, DeepHoney, FontStyle.Bold, false);
            UiKit.Label(card, big, 88, new Vector2(0.05f, 0.6f), new Vector2(0.95f, 0.77f),
                TextAnchor.MiddleCenter, bigColor, FontStyle.Bold, false);

            string body =
                $"Банок утащено: {stats.jars}/{stats.jarsNeeded}\n" +
                $"Ужалили: {stats.stings} раз\n" +
                $"Пчёл сбито мухобойкой: {stats.swats}\n" +
                $"Дымарь: {stats.smokes} раз\n" +
                $"Перекатов: {stats.dodges}";
            UiKit.Label(card, body, 40, new Vector2(0.08f, 0.27f), new Vector2(0.92f, 0.6f), TextAnchor.MiddleLeft,
                UiKit.Ink, FontStyle.Normal, false);
            UiKit.Label(card, $"Побегов всего: {p.escapeWins} из {p.escapeAttempts}", 38, new Vector2(0.05f, 0.18f),
                new Vector2(0.95f, 0.27f), TextAnchor.MiddleCenter, UiKit.Ink, FontStyle.Bold, false);

            UiKit.MakeButton(s, "Ещё раз", new Vector2(0.06f, 0.07f), new Vector2(0.6f, 0.17f), UiKit.DangerBg,
                Color.white, () => GameFlow.I.StartEscape(), 60);
            UiKit.MakeButton(s, "В меню", new Vector2(0.63f, 0.07f), new Vector2(0.94f, 0.17f), UiKit.Muted,
                Color.white, () => GameFlow.I.ShowHub(), 44);
        }

        static HumanController CurrentHuman()
        {
            var flow = GameFlow.I;
            if (flow == null || flow.Escape == null) return null;
            return flow.Escape.Human;
        }

        static string FormatTime(float seconds)
        {
            int s = Mathf.Max(0, Mathf.RoundToInt(seconds));
            return $"{s / 60}:{s % 60:00}";
        }

        // ── Реплики и всплывашки ───────────────────────────────

        public void Say(string line, float seconds)
        {
            _sayText.text = line;
            _sayUntil = Time.time + seconds;
        }

        public void Toast(string text)
        {
            _toastText.text = text;
            _toastAt = Time.time;
        }

        void Update()
        {
            _sayGroup.alpha = Mathf.MoveTowards(_sayGroup.alpha, Time.time < _sayUntil ? 1f : 0f, Time.deltaTime * 5f);

            float tt = Time.time - _toastAt;
            _toastGroup.alpha = tt < 1.6f ? 1f : Mathf.Clamp01(1f - (tt - 1.6f) / 0.4f);
            _toast.anchoredPosition = new Vector2(0f, Mathf.Min(tt, 2f) * 60f);

            if (_questionActive)
            {
                float qt = Time.time - _questionAt;
                if (_silence == 0 && qt > 5f)
                {
                    _silence = 1;
                    Say(Lines.Silence[0], 3f);
                }
                else if (_silence == 1 && qt > 11f)
                {
                    _silence = 2;
                    Say(Lines.Silence[1], 3f);
                }
            }

            if (_changeBtn != null)
            {
                var p = PlayerProfile.Current;
                if (p.CanChangeAnswer)
                {
                    int sec = p.SecondsToChange;
                    _changeLabel.text = $"Я передумал · {sec / 60}:{sec % 60:00}";
                }
                else
                {
                    Destroy(_changeBtn.gameObject);
                    _changeBtn = null;
                }
            }

            if (_hudActive) UpdateHud();
            if (_escapeHudActive) UpdateEscapeHud();
        }

        void UpdateHud()
        {
            var flow = GameFlow.I;
            if (flow == null || flow.Stats == null) return;
            var bee = flow.Bee;

            if (bee != null)
            {
                _pollenText.text = $"Пыльца {bee.Pollen}/{bee.Capacity}";
                _pollenFill.anchorMax = new Vector2(Mathf.Max(0.02f, bee.Load), 1f);

                Vector3 d = flow.World.HivePosition - bee.transform.position;
                d.y = 0f;
                float dist = d.magnitude;
                _hiveText.text = dist < 2.5f ? "Ты у улья" : $"Улей · {Mathf.RoundToInt(dist)} м";
                float camYaw = Camera.main != null ? Camera.main.transform.eulerAngles.y : 0f;
                float angle = Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg - camYaw;
                _arrow.localRotation = Quaternion.Euler(0f, 0f, -angle);
            }

            int secs = Mathf.CeilToInt(Mathf.Max(0f, flow.TimeLeft));
            _timerText.text = $"{secs / 60}:{secs % 60:00}";
            _timerText.color = secs <= 20 ? new Color(1f, 0.55f, 0.5f) : Color.white;
            _honeyText.text = $"Мёд +{flow.Stats.honeyMade}";

            float ht = Time.time - _hintAt;
            _hintGroup.alpha = ht < 8f ? 1f : Mathf.Clamp01(1f - (ht - 8f) / 1.5f);
        }
    }
}
