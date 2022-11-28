// Server app image shouldn't contain compiled build scripts
#if UNITY_EDITOR

using System;
using System.Linq;
using UnityEditor;
using UnityEngine;

public class BuildScript
{
    // Private members

    private static BuildTarget m_buildTarget 
        = BuildTarget.StandaloneLinux64;

    private static string m_buildTargetLocation;

    private static void SetupVariables()
    {
        PlayerSettings.productName = "Dummy Server App";
        PlayerSettings.companyName = "Lncxr";
        PlayerSettings.forceSingleInstance = true;
        PlayerSettings.bundleVersion = "0.0.1";

        string projectPath = Application.dataPath;
        projectPath = projectPath.Replace("/Assets", "");

        m_buildTargetLocation = projectPath + "/Builds";
    }

    private static string[] GetScenes()
    {
        return EditorBuildSettings.scenes.Where(s => s.enabled)
            .Select(s => s.path)
            .ToArray();
    }

    // Publicly-accessible build methods

    public static void Linux()
    {
        // Try-catch for testing, no diagnostics in 'silent mode' (CLI batch mode)
        try
        {
            SetupVariables();

            // Your BuildTarget must be installed for your Editor ver. or this will silently fail
            BuildPipeline.BuildPlayer(GetScenes(), m_buildTargetLocation + "/dummy-server-app.x86_64",
                m_buildTarget, BuildOptions.None);
        }
        catch (Exception exception)
        {
            Debug.Log($"Exception in BuildScript : {exception}");
            throw;
        }
    }
}
#endif