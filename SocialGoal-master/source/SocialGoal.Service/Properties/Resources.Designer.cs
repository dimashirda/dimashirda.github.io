﻿//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by a tool.
//     Runtime Version:4.0.30319.18408
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

namespace SocialGoal.Service.Properties {
    using System;
    
    
    /// <summary>
    ///   A strongly-typed resource class, for looking up localized strings, etc.
    /// </summary>
    // This class was auto-generated by the StronglyTypedResourceBuilder
    // class via a tool like ResGen or Visual Studio.
    // To add or remove a member, edit your .ResX file then rerun ResGen
    // with the /str option, or rebuild your VS project.
    [global::System.CodeDom.Compiler.GeneratedCodeAttribute("System.Resources.Tools.StronglyTypedResourceBuilder", "4.0.0.0")]
    [global::System.Diagnostics.DebuggerNonUserCodeAttribute()]
    [global::System.Runtime.CompilerServices.CompilerGeneratedAttribute()]
    internal class Resources {
        
        private static global::System.Resources.ResourceManager resourceMan;
        
        private static global::System.Globalization.CultureInfo resourceCulture;
        
        [global::System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1811:AvoidUncalledPrivateCode")]
        internal Resources() {
        }
        
        /// <summary>
        ///   Returns the cached ResourceManager instance used by this class.
        /// </summary>
        [global::System.ComponentModel.EditorBrowsableAttribute(global::System.ComponentModel.EditorBrowsableState.Advanced)]
        internal static global::System.Resources.ResourceManager ResourceManager {
            get {
                if (object.ReferenceEquals(resourceMan, null)) {
                    global::System.Resources.ResourceManager temp = new global::System.Resources.ResourceManager("SocialGoal.Service.Properties.Resources", typeof(Resources).Assembly);
                    resourceMan = temp;
                }
                return resourceMan;
            }
        }
        
        /// <summary>
        ///   Overrides the current thread's CurrentUICulture property for all
        ///   resource lookups using this strongly typed resource class.
        /// </summary>
        [global::System.ComponentModel.EditorBrowsableAttribute(global::System.ComponentModel.EditorBrowsableState.Advanced)]
        internal static global::System.Globalization.CultureInfo Culture {
            get {
                return resourceCulture;
            }
            set {
                resourceCulture = value;
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Email Id already registered..
        /// </summary>
        internal static string EmailExixts {
            get {
                return ResourceManager.GetString("EmailExixts", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Enddate cannot be before Start date..
        /// </summary>
        internal static string EndDate {
            get {
                return ResourceManager.GetString("EndDate", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Entered Date cannot be EndDate  Since the Last Updated Entered Date cannot be EndDate  Since the Last Updated Date is.
        /// </summary>
        internal static string EndDateNotValid {
            get {
                return ResourceManager.GetString("EndDateNotValid", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Focus already exists..
        /// </summary>
        internal static string FocusExists {
            get {
                return ResourceManager.GetString("FocusExists", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Goal already exists..
        /// </summary>
        internal static string GoalExists {
            get {
                return ResourceManager.GetString("GoalExists", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Group already exists..
        /// </summary>
        internal static string GroupExists {
            get {
                return ResourceManager.GetString("GroupExists", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Already joined this group..
        /// </summary>
        internal static string PersonJoined {
            get {
                return ResourceManager.GetString("PersonJoined", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Already supporting this goal..
        /// </summary>
        internal static string PersonSupporting {
            get {
                return ResourceManager.GetString("PersonSupporting", resourceCulture);
            }
        }
        
        /// <summary>
        ///   Looks up a localized string similar to Entered Date cannot be Start Date  Since the First Updated Date is.
        /// </summary>
        internal static string StartDate {
            get {
                return ResourceManager.GetString("StartDate", resourceCulture);
            }
        }
    }
}
