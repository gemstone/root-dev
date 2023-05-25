//******************************************************************************************************
//  ConsoleHelpers.cs - Gbtc
//
//  Copyright © 2022, Grid Protection Alliance.  All Rights Reserved.
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
using System.Collections.Generic;
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

        public static void ShowError(string errorMessage)
        {
            Console.Error.WriteLine($"ERROR: {errorMessage}{NewLine}");
            ShowUsage();
        }

        public static bool ValidateArgs(string[] receivedArgs)
        {
            if (receivedArgs.Length == ArgNames.Length)
                return true;

            ShowError($"Invalid number of command line arguments specified. Received {receivedArgs.Length}, expected {ArgNames.Length}.");

            return false;
        }

        public static int HandleException(Exception ex)
        {
            ShowError(ex.Message);

            return ExitException;
        }

        public static bool ValidateGemstoneProjectPath(List<string> projectFilePaths, string projectFileSearchPath, out int result)
        {
            if (File.Exists(projectFileSearchPath))
            {
                if (!projectFileSearchPath.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase))
                {
                    ShowError("Bad project name specified.");
                    result = ExitBadFileName;

                    return false;
                }

                projectFilePaths.Add(projectFileSearchPath);
            }
            else if (Directory.Exists(projectFileSearchPath))
            {
                // For the recursive search, ignore hidden folders like .git or .vs
                static IEnumerable<string> EnumerateDirectories(string path) => Directory
                    .EnumerateDirectories(path)
                    .Where(path => !Path.GetFileName(path).StartsWith('.'))
                    .SelectMany(EnumerateDirectories)
                    .Prepend(path);

                IEnumerable<string> projectFileSearch = EnumerateDirectories(projectFileSearchPath)
                    .SelectMany(subdir => Directory.GetFiles(subdir, "*.csproj", SearchOption.AllDirectories));

                projectFilePaths.AddRange(projectFileSearch);

                if (!projectFilePaths.Any())
                {
                    ShowError("Bad project path specified.");
                    result = ExitBadPath;

                    return false;
                }
            }
            else
            {
                ShowError("Bad project name or path specified.");
                result = ExitBadFileName;

                return false;
            }

            result = ExitSuccess;

            return true;
        }

        public static XmlDocument OpenProjectFile(string projectFilePath)
        {
            XmlDocument projectFile = new() { PreserveWhitespace = true };
            projectFile.Load(projectFilePath);

            return projectFile;
        }

        public static bool TryGetVersionNode(XmlDocument projectFile, out XmlNode versionNode)
        {
            versionNode = projectFile.SelectSingleNode("Project/PropertyGroup/Version");
            return versionNode is not null;
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