//******************************************************************************************************
//  Program.cs - Gbtc
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
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Xml;
using static System.Environment;

namespace UpdateVersion
{
    public class Program
    {
        private static readonly string[] ARGS = { "ProjectFileOrPath", "Version" };
        private static readonly string[] EXAMPLES = { @"""D:\Projects\gemstone\io\src\Gemstone.IO""", "1.0.2-beta" };
        private const int EXIT_SUCCESS = 0;
        private const int EXIT_BAD_ARGS = 0xA0;
        private const int EXIT_BAD_FILENAME = 0xA1;
        private const int EXIT_BAD_PATH = 0xA2;
        private const int EXIT_NO_VERSION = 0xA3;
        private const int EXIT_EXCEPTION = 0xFF;
        
        public static int Main(string[] args)
        {
            try
            {
                if (args.Length != ARGS.Length)
                {
                    Console.Error.WriteLine($"ERROR: Invalid number of command line arguments specified. Received {args.Length}, expected {ARGS.Length}.{NewLine}");
                    ShowUsage();
                    return EXIT_BAD_ARGS;
                }

                string projectFilePath = args[0].Trim();
                string version = args[1].Trim();

                // See if a folder name was provided instead of an actual project file name
                if (!File.Exists(projectFilePath))
                {
                    if (projectFilePath.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase) || !Directory.Exists(projectFilePath))
                    {
                        Console.Error.WriteLine($"ERROR: Bad project name or path specified.{NewLine}");
                        ShowUsage();
                        return EXIT_BAD_FILENAME;
                    }

                    projectFilePath = Directory.GetFiles(projectFilePath, "*.csproj").FirstOrDefault();

                    if (string.IsNullOrEmpty(projectFilePath) || !File.Exists(projectFilePath))
                    {
                        Console.Error.WriteLine($"ERROR: Bad project path specified.{NewLine}");
                        ShowUsage();
                        return EXIT_BAD_PATH;
                    }
                }

                // Load XML project file
                XmlDocument projectFile = new XmlDocument { PreserveWhitespace = true };
                projectFile.Load(projectFilePath);

                // Find version number
                XmlNode versionNode = projectFile.SelectSingleNode("Project/PropertyGroup/Version");

                if (versionNode == null)
                {
                    Console.Error.WriteLine($"ERROR: No <Version> tag found.{NewLine}");
                    ShowUsage();
                    return EXIT_NO_VERSION;
                }

                // Update version number
                versionNode.InnerText = version;

                // Update informational version tags
                XmlNodeList infoVersionNodes = projectFile.SelectNodes("Project/PropertyGroup/InformationalVersion");

                foreach (XmlNode infoVersionNode in infoVersionNodes)
                {
                    string infoVersion = infoVersionNode.InnerText;

                    // If contains space, assuming node is prefixed with version number up to first space
                    infoVersion = infoVersion.Contains(' ') ? $"{version}{infoVersion.Substring(infoVersion.IndexOf(' '))}" : version;
                    infoVersionNode.InnerText = infoVersion;
                }

                // Get raw version without any suffix, e.g., remove any -beta suffix
                string rawVersion = version;

                if (rawVersion.Contains('-'))
                    rawVersion = rawVersion.Substring(0, rawVersion.IndexOf('-'));

                // Update Gemstone package reference versions
                XmlNodeList packageReferenceNodes = projectFile.SelectNodes("Project/ItemGroup/PackageReference[starts-with(@Include,'Gemstone.')]");

                foreach (XmlNode packageReferenceNode in packageReferenceNodes)
                    packageReferenceNode.Attributes["Version"].Value = rawVersion;

                projectFile.Save(projectFilePath);

                Console.WriteLine($"Successfully updated version to \"{version}\" in \"{Path.GetFileName(projectFilePath)}\" project file.");

                return EXIT_SUCCESS;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"ERROR: {ex.Message}{NewLine}");
                return EXIT_EXCEPTION;
            }
        }

        private static void ShowUsage()
        {
            string assemblyName = Assembly.GetExecutingAssembly().GetName().Name;

            Console.Error.WriteLine($"USAGE:{NewLine}");
            Console.Error.WriteLine($"    {assemblyName} {string.Join(' ', ARGS)}{NewLine}");
            Console.Error.WriteLine($"EXAMPLE:{NewLine}");
            Console.Error.WriteLine($"    {assemblyName} {string.Join(' ', EXAMPLES)}{NewLine}");
        }
    }
}
