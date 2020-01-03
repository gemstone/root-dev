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
using System.IO;
using System.Linq;
using System.Reflection;
using System.Xml;
using static System.Environment;

namespace ReadVersion
{
    public class Program
    {
        private static readonly string[] ARGS = { "ProjectFileOrPath" };
        private static readonly string[] EXAMPLES = { @"""D:\Projects\gemstone\io\src\Gemstone.IO"""  };
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
                XmlDocument projectFile = new XmlDocument();
                projectFile.Load(projectFilePath);

                // Find version number
                string version = projectFile.SelectSingleNode("Project/PropertyGroup/Version")?.InnerText;

                if (string.IsNullOrWhiteSpace(version))
                {
                    Console.Error.WriteLine($"ERROR: No <Version> tag found.{NewLine}");
                    ShowUsage();
                    return EXIT_NO_VERSION;
                }

                // Get raw version without any suffix, e.g., remove any -beta suffix
                if (version.Contains('-'))
                    version = version.Substring(0, version.IndexOf('-'));

                // Write version information to console
                Console.WriteLine(version);

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
