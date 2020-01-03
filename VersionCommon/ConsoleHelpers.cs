//******************************************************************************************************
//  ConsoleHelpers.cs - Gbtc
//
//  Copyright © 2020, Grid Protection Alliance.  All Rights Reserved.
//
//  Licensed to the Grid Protection Alliance (GPA) under one or more contributor license agreements. See
//  the NOTICE file distributed with this work for additional information regarding copyright ownership.
//  The GPA licenses this file to you under the MIT License (MIT), the "License"; you may not use this
//  file except in compliance with the License. You may obtain a copy of the License at:
//
//      http://opensource.org/licenses/MIT
//
//  Unless agreed to in writing, the subject software distributed under the License is distributed on an
//  "AS-IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. Refer to the
//  License for the specific language governing permissions and limitations.
//
//  Code Modification History:
//  ----------------------------------------------------------------------------------------------------
//  01/03/2020 - J. Ritchie Carroll
//       Generated original version of source code.
//
//******************************************************************************************************

using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Xml;
using static System.Environment;

namespace VersionCommon
{
    public static class ConsoleHelpers
    {
        public static string[] ArgNames = Array.Empty<string>();
        public static string[] ArgExamples = Array.Empty<string>();

        public const int ExitSuccess = 0;
        public const int ExitBadArgs = 0xA0;
        public const int ExitBadFileName = 0xA1;
        public const int ExitBadPath = 0xA2;
        public const int ExitNoVersion = 0xA3;
        public const int ExitException = 0xFF;

        public static void ShowUsage()
        {
            string assemblyName = Assembly.GetExecutingAssembly().GetName().Name;

            Console.Error.WriteLine($"USAGE:{NewLine}");
            Console.Error.WriteLine($"    {assemblyName} {string.Join(' ', ArgNames)}{NewLine}");

            Console.Error.WriteLine($"EXAMPLE:{NewLine}");
            Console.Error.WriteLine($"    {assemblyName} {string.Join(' ', ArgExamples)}{NewLine}");
        }

        public static bool ValidateArgs(string[] receivedArgs)
        {
            if (receivedArgs.Length == ArgNames.Length)
                return true;

            ShowUsage();
            Console.Error.WriteLine($"ERROR: Invalid number of command line arguments specified. Received {receivedArgs.Length}, expected {ArgNames.Length}.{NewLine}");

            return false;
        }

        public static int HandleException(Exception ex)
        {
            ShowUsage();
            Console.Error.WriteLine($"ERROR: {ex.Message}{NewLine}");

            return ExitException;
        }

        public static bool ValidateGemstoneProjectPath(ref string projectFilePath, out int result)
        {
            // See if a folder name was provided instead of an actual project file name
            if (!File.Exists(projectFilePath))
            {
                if (projectFilePath.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase) || !Directory.Exists(projectFilePath))
                {
                    ShowUsage();
                    Console.Error.WriteLine($"ERROR: Bad project name or path specified.{NewLine}");
                    result = ExitBadFileName;

                    return false;
                }

                // Directory name specified, look for a project file
                string firstProjectFile = Directory.GetFiles(projectFilePath, "*.csproj").FirstOrDefault();

                if (string.IsNullOrEmpty(firstProjectFile))
                {
                    // See if input path only specified root project folder
                    string projectFolderName = GetLastDirectoryName(projectFilePath);

                    // "Gemstone.Common" project folder structure is special from a namespace perspective as its root namespace is just "Gemstone"
                    projectFolderName = projectFolderName.Equals("common", StringComparison.OrdinalIgnoreCase) ? "" : $".{projectFolderName}";

                    // Look for project file again
                    firstProjectFile = Directory.GetFiles(Path.Combine(projectFilePath, $"src\\Gemstone{projectFolderName}"), "*.csproj").FirstOrDefault();

                    if (string.IsNullOrEmpty(firstProjectFile))
                    {
                        ShowUsage();
                        Console.Error.WriteLine($"ERROR: Bad project path specified.{NewLine}");
                        result = ExitBadPath;

                        return false;
                    }
                }

                projectFilePath = firstProjectFile;
            }

            result = ExitSuccess;

            return true;
        }

        public static XmlDocument OpenProjectFile(string projectFilePath)
        {
            XmlDocument projectFile = new XmlDocument { PreserveWhitespace = true };
            projectFile.Load(projectFilePath);

            return projectFile;
        }

        public static bool TryGetVersionNode(XmlDocument projectFile, out XmlNode versionNode)
        {
            versionNode = projectFile.SelectSingleNode("Project/PropertyGroup/Version");

            if (versionNode == null)
            {
                ShowUsage();
                Console.Error.WriteLine($"ERROR: No <Version> tag found.{NewLine}");

                return false;
            }

            return true;
        }

        public static string GetRawVersion(string version)
        {
            if (version.Contains('-'))
                version = version.Substring(0, version.IndexOf('-'));

            return version;
        }

        private static string GetLastDirectoryName(string filePath)
        {
            int index;
            char[] dirVolChars = { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar, Path.VolumeSeparatorChar };

            char suffixChar = filePath[^1];

            // Test for case where valid path does not end in directory separator, Path.GetDirectoryName assumes
            // this is a file name - whether it exists or not :-(
            if (suffixChar != Path.DirectorySeparatorChar && suffixChar != Path.AltDirectorySeparatorChar)
                filePath += Path.DirectorySeparatorChar;

            // Remove file name from path
            filePath = Path.GetDirectoryName(filePath);

            // Remove any trailing directory separator characters from the file path
            suffixChar = filePath[^1];

            while ((suffixChar == Path.DirectorySeparatorChar || suffixChar == Path.AltDirectorySeparatorChar) && filePath.Length > 0)
            {
                filePath = filePath[..^1];

                if (filePath.Length > 0)
                    suffixChar = filePath[^1];
            }

            // Keep going through the file path until all directory separator characters are removed
            while ((index = filePath.IndexOfAny(dirVolChars)) > -1)
                filePath = filePath.Substring(index + 1);

            return filePath;
        }
    }
}