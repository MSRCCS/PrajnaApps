using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http;
using System.Web.Routing;

namespace ImageDescriberV3
{
    public class WebApplication : System.Web.HttpApplication
    {
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1822:MarkMembersAsStatic")]
        // Bot framework code
        protected void Application_Start()
        {
            GlobalConfiguration.Configure(WebConfig.Register);
        }
    }
}
