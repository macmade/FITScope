/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2025 Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Cocoa

@main
public class ApplicationDelegate: NSObject, NSApplicationDelegate
{
    @MainActor private var updater               = GitHubUpdater( owner: "macmade", repository: "FITScope" )
    @MainActor private var aboutWindowController = AboutWindowController()
    @MainActor private var mainWindowControllers = [ MainWindowController ]()
    
    public func applicationDidFinishLaunching( _ notification: Notification )
    {
        self.openDocument( nil )
        self.updater?.checkForUpdatesInBackground()
    }

    public func applicationWillTerminate( _ notification: Notification )
    {}

    public func applicationSupportsSecureRestorableState( _ app: NSApplication ) -> Bool
    {
        false
    }
    
    public func application( _ application: NSApplication, open urls: [ URL ] )
    {
        self.open( urls: urls )
    }
    
    @IBAction
    public func openDocument( _ sender: Any? )
    {
        let panel                     = NSOpenPanel()
        panel.canChooseFiles          = true
        panel.canChooseDirectories    = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories    = true
        panel.allowedContentTypes     = [ .fits ]
        
        if panel.runModal() == .OK
        {
            self.open( urls: panel.urls )
        }
    }
    
    @IBAction
    public func checkForUpdates( _ sender: Any? )
    {
        guard let updater = self.updater else
        {
            NSSound.beep()
            
            return
        }
        
        updater.checkForUpdates()
    }
    
    @IBAction
    public func showHelp( _ sender: Any? )
    {
        guard let url = URL( string: "https://github.com/macmade/FITScope" )
        else
        {
            NSSound.beep()
            
            return
        }
        
        NSWorkspace.shared.open( url )
    }
    
    @IBAction
    public func showAboutWindow( _ sender: Any? )
    {
        guard let window = self.aboutWindowController.window else
        {
            NSSound.beep()
            
            return
        }
        
        if window.isVisible == false
        {
            window.center()
        }
        
        window.makeKeyAndOrderFront( sender )
    }
    
    @MainActor
    private func open( urls: [ URL ] )
    {
        urls.forEach
        {
            let controller = MainWindowController( url: $0 )
            {
                [ weak self ] controller in self?.mainWindowControllers.removeAll
                {
                    $0 === controller
                }
            }
            
            self.mainWindowControllers.append( controller )
            controller.window?.makeKeyAndOrderFront( nil )
        }
    }
}
