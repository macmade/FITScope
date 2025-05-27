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

public class InfoWindowController: NSWindowController
{
    private var name: String
    private var file: FITSFile

    @objc public dynamic var sections:        [ InfoSection ]
    @objc public dynamic var selectedSection: InfoSection?

    @IBOutlet private var sectionsController: NSArrayController?
    @IBOutlet private var valuesController:   NSArrayController?
    @IBOutlet private var valuesTableView:    NSTableView?
    @IBOutlet private var optionsMenu:        NSMenu?

    private var sectionSelectionObserver: NSKeyValueObservation?

    public init( name: String, file: FITSFile )
    {
        self.name     = name
        self.file     = file
        self.sections = InfoSection.info( from: file.sections )

        super.init( window: nil )
    }

    required init?( coder: NSCoder )
    {
        nil
    }

    public override var windowNibName: NSNib.Name?
    {
        "InfoWindowController"
    }

    public override func windowDidLoad()
    {
        super.windowDidLoad()

        self.window?.title                     = self.name
        self.selectedSection                   = self.sections.first
        self.valuesController?.sortDescriptors = [ NSSortDescriptor( keyPath: \InfoField.index, ascending: true ) ]

        self.valuesTableView?.sizeLastColumnToFit()
        self.valuesTableView?.scrollRowToVisible( 0 )
    }

    @IBAction
    private func showOptions( _ sender: Any? )
    {
        guard let view  = sender as? NSView,
              let menu  = self.optionsMenu,
              let event = NSApp.currentEvent
        else
        {
            NSSound.beep()

            return
        }

        NSMenu.popUpContextMenu( menu, with: event, for: view )
    }

    @IBAction
    private func exportToTSV( _ sender: Any? )
    {
        guard let window = self.window
        else
        {
            NSSound.beep()

            return
        }

        let panel                  = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes  = [ .tabSeparatedText ]
        panel.nameFieldStringValue = NSString( string: self.name ).deletingPathExtension

        panel.beginSheetModal( for: window )
        {
            if $0 == .OK, let url = panel.url
            {
                self.exportToTSV( url: url )
            }
        }
    }

    private func exportToTSV( url: URL )
    {
        let selected   = self.valuesController?.selectedObjects as? [ InfoField ] ?? []
        let all        = self.valuesController?.arrangedObjects as? [ InfoField ] ?? []
        let properties = selected.isEmpty ? all : selected
        let tsv        = properties.map
        {
            InfoWindowController.tsvForProperty( $0 )
        }
        .joined( separator: "\n" )

        guard let data = tsv.data( using: .utf8 )
        else
        {
            let alert             = NSAlert()
            alert.messageText     = "Error"
            alert.informativeText = "Unable to create TSV data from selected properties."

            alert.showOnWindow( self.window, completion: nil )

            return
        }

        do
        {
            try data.write( to: url )
        }
        catch
        {
            let alert             = NSAlert()
            alert.messageText     = "Error"
            alert.informativeText = "Unable to write TSV data to file: \( error.localizedDescription )"

            alert.showOnWindow( self.window, completion: nil )

            return
        }
    }

    private class func tsvForProperty( _ property: InfoField ) -> String
    {
        let values = [
            property.name,
            property.kind,
            property.value   ?? "",
            property.comment ?? "",
        ]
        .map
        {
            $0.replacingOccurrences( of: "\t", with: "\\t" )
        }
        .map
        {
            $0.replacingOccurrences( of: "\n", with: "\\n" )
        }

        return values.joined( separator: "\t" )
    }
}
