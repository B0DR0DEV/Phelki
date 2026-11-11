using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Phelki.EditorTools
{
    /// <summary>
    /// Сборка APK. Её вызывает GitHub Actions (GameCI), а вручную —
    /// меню Phelki → Собрать APK. Сама создаёт сцену, если её нет,
    /// и выставляет настройки Android: имя, пакет, портрет, IL2CPP ARM64.
    /// </summary>
    public static class CiBuild
    {
        const string ScenePath = "Assets/Phelki/Scenes/Main.unity";
        const string PackageName = "com.b0dr0dev.phelki";
        const string ProductName = "Пчёлок уважаешь?";
        const string DefaultOutput = "build/Android/Phelki.apk";

        [MenuItem("Phelki/Собрать APK")]
        static void BuildFromMenu() => BuildAndroid();

        [MenuItem("Phelki/Создать главную сцену")]
        static void CreateSceneFromMenu()
        {
            EnsureScene();
            EditorSceneManager.OpenScene(ScenePath);
        }

        public static void BuildAndroid()
        {
            try
            {
                string output = Arg("-customBuildPath") ?? DefaultOutput;
                if (!output.EndsWith(".apk", StringComparison.OrdinalIgnoreCase))
                    output = Path.Combine(output, "Phelki.apk");
                string dir = Path.GetDirectoryName(output);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);

                EnsureScene();
                ConfigurePlayer();

                EditorUserBuildSettings.buildAppBundle = false;
                var options = new BuildPlayerOptions
                {
                    scenes = new[] { ScenePath },
                    locationPathName = output,
                    target = BuildTarget.Android,
                    targetGroup = BuildTargetGroup.Android,
                    options = BuildOptions.None
                };

                var report = BuildPipeline.BuildPlayer(options);
                var summary = report.summary;
                Debug.Log($"[Phelki] Сборка: {summary.result}, ошибок {summary.totalErrors}, " +
                          $"размер {summary.totalSize / (1024 * 1024)} МБ, файл {output}");

                if (summary.result != BuildResult.Succeeded) Fail("сборка не удалась, смотри ошибки выше");
                else if (Application.isBatchMode) EditorApplication.Exit(0);
            }
            catch (Exception e)
            {
                Debug.LogException(e);
                Fail(e.Message);
            }
        }

        static void Fail(string reason)
        {
            Debug.LogError("[Phelki] " + reason);
            if (Application.isBatchMode) EditorApplication.Exit(1);
        }

        /// <summary>
        /// Главная сцена: камера и свет по умолчанию. Всё остальное
        /// собирает Bootstrap при запуске, поэтому сцена может быть почти пустой.
        /// </summary>
        static void EnsureScene()
        {
            if (!File.Exists(ScenePath))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(ScenePath));
                var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
                EditorSceneManager.SaveScene(scene, ScenePath);
                AssetDatabase.Refresh();
                Debug.Log("[Phelki] Создана главная сцена " + ScenePath);
            }
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        }

        static void ConfigurePlayer()
        {
            var android = NamedBuildTarget.Android;

            PlayerSettings.companyName = "B0DR0DEV";
            PlayerSettings.productName = ProductName;
            PlayerSettings.SetApplicationIdentifier(android, PackageName);

            // Номер сборки из GitHub Actions — чтобы новая версия ставилась поверх старой
            if (int.TryParse(Arg("-runNumber"), out int run) && run > 0)
            {
                PlayerSettings.Android.bundleVersionCode = run;
                PlayerSettings.bundleVersion = $"0.1.{run}";
            }

            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;

            // Современные телефоны бывают только 64-битными — нужен IL2CPP + ARM64
            PlayerSettings.SetScriptingBackend(android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;

            // Без своего ключа подписи APK подписывается отладочным ключом — для тестов этого хватает
            PlayerSettings.Android.useCustomKeystore = false;
        }

        static string Arg(string name)
        {
            var args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length - 1; i++)
                if (args[i] == name) return args[i + 1];
            return null;
        }
    }
}
