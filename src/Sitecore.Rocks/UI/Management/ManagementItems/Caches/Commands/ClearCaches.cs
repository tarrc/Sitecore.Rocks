// � 2015-2016 Sitecore Corporation A/S. All rights reserved.

using System.Collections.Generic;
using System.Windows;
using Sitecore.Rocks.Commands;
using Sitecore.Rocks.Data;
using Sitecore.Rocks.Data.DataServices;

namespace Sitecore.Rocks.UI.Management.ManagementItems.Caches.Commands
{
    [Command]
    public class ClearCaches : CommandBase
    {
        public ClearCaches()
        {
            Text = Resources.ClearCaches_ClearCaches_Clear___;
            Group = "Clear";
            SortingValue = 1000;
        }

        public override bool CanExecute(object parameter)
        {
            var context = parameter as CacheViewerContext;
            if (context == null)
            {
                return false;
            }

            if (context.CacheViewer.Context.Site.SitecoreVersion < Constants.Versions.Version82)
            {
                return false;
            }

            var selectedItems = context.CacheViewer.CacheList.SelectedItems;
            if (selectedItems.Count <= 0)
            {
                return false;
            }

            return true;
        }

        public override void Execute(object parameter)
        {
            var context = parameter as CacheViewerContext;
            if (context == null)
            {
                return;
            }

            string text;
            var selectedItems = context.CacheViewer.CacheList.SelectedItems;

            if (selectedItems.Count == 1)
            {
                var cache = (CacheViewer.CacheDescriptor)selectedItems[0];
                text = string.Format("Are you sure you want to clear the \"{0}\" cache?", cache.Name);
            }
            else
            {
                text = string.Format("Are you sure you want to clear these {0} caches?", selectedItems.Count);
            }

            if (AppHost.MessageBox(text, "Confirmation", MessageBoxButton.OKCancel, MessageBoxImage.Question) != MessageBoxResult.OK)
            {
                return;
            }

            var caches = new List<string>();
            foreach (var selectedItem in selectedItems)
            {
                var cache = selectedItem as CacheViewer.CacheDescriptor;
                if (cache != null)
                {
                    caches.Add(cache.Name);
                }
            }

            ExecuteCompleted completed = delegate(string response, ExecuteResult result)
            {
                if (!DataService.HandleExecute(response, result))
                {
                    return;
                }

                context.CacheViewer.LoadCaches();
            };

            context.CacheViewer.Context.Site.DataService.ExecuteAsync("Caches.Clear", completed, string.Join("|", caches));
        }
    }
}
