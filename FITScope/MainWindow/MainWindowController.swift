/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Cocoa
import SwiftFITS
import SwiftUtilities

public class MainWindowController: NSWindowController, NSWindowDelegate
{
    @MainActor private var url:                  URL
    @MainActor private var onClose:              ( ( MainWindowController ) -> Void )?
    @MainActor private var file:                 FITSFile?
    @MainActor private var infoWindowController: InfoWindowController?

    @objc private dynamic var loading = false
    @objc private dynamic var image:    NSImage?

    public init( url: URL, onClose: ( ( MainWindowController ) -> Void )? )
    {
        self.url     = url
        self.onClose = onClose

        super.init( window: nil )
    }

    required init?( coder: NSCoder )
    {
        nil
    }

    public override var windowNibName: NSNib.Name?
    {
        "MainWindowController"
    }

    public override func windowDidLoad()
    {
        super.windowDidLoad()

        self.window?.delegate = self
        self.window?.title    = self.url.lastPathComponent
        self.loading          = true
        let url               = self.url

        Task.detached( priority: .userInitiated )
        {
            do
            {
                let file = try FITSFile( url: url )
                let send = UnsafeSendable( file )

                await MainActor.run
                {
                    self.file = send.value
                }

                // TODO: Support for extension data
                guard file.sections.count >= 2, file.sections[ 0 ].kind == .header, file.sections[ 1 ].kind == .data
                else
                {
                    throw RuntimeError( message: "No data section found" )
                }

                let image = try ImageRenderer.render( data: file.sections[ 1 ].data, properties: file.sections[ 0 ].properties )

                Task
                {
                    @MainActor in

                    self.loading = false
                    self.image   = NSImage( cgImage: image, size: NSSize( width: image.width, height: image.height ) )
                }
            }
            catch
            {
                Task
                {
                    @MainActor in

                    self.loading          = false
                    let alert             = NSAlert()
                    alert.messageText     = "Cannot Read FITS File"
                    alert.informativeText = error.localizedDescription

                    alert.showOnWindow( self.window, completion: nil )
                }
            }
        }
    }

    public func windowWillClose( _ notification: Notification )
    {
        self.onClose?( self )
    }

    @IBAction
    public func showInfo( _ sender: Any? )
    {
        guard let file = self.file
        else
        {
            NSSound.beep()

            return
        }

        if self.infoWindowController == nil
        {
            self.infoWindowController = InfoWindowController( name: self.url.lastPathComponent, file: file )
        }

        self.infoWindowController?.window?.makeKeyAndOrderFront( sender )
    }
}
