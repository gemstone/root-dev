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
using System.Xml;
using static VersionCommon.ConsoleHelpers;

namespace ReadVersion
{
    public class Program
    {
        public static int Main(string[] args)
        {
            ArgNames = new[] { "ProjectFileOrPath" };
            ArgExamples = new[] { @"""D:\Projects\gemstone\io""" };

            try
            {
                if (!ValidateArgs(args))
                    return ExitBadArgs;

                string projectFilePath = args[0].Trim();
                
                if (!ValidateGemstoneProjectPath(ref projectFilePath, out int result))
                    return result;

                // Load XML project file
                XmlDocument projectFile = OpenProjectFile(projectFilePath);

                // Get version number
                if (!TryGetVersionNode(projectFile, out XmlNode versionNode))
                    return ExitNoVersion;

                // Write version information to console without any suffix, e.g., remove any -beta suffix
                Console.WriteLine(GetRawVersion(versionNode.InnerText));

                return ExitSuccess;
            }
            catch (Exception ex)
            {
                return HandleException(ex);
            }
        }
    }
}
