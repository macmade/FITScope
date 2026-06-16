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

import Combine
import Foundation
import SwiftUI

/// The state of a single window: the ordered list of open files and the current
/// selection. Each window owns one instance; windows are fully independent.
@MainActor
public final class WindowModel: ObservableObject
{
    /// The open files, in the order they were opened.
    @Published public private( set ) var files: [ OpenFile ] = []

    /// The id of the currently selected file, or `nil` when none is selected.
    @Published public var selectedFileID: OpenFile.ID?

    /// Creates an empty window model.
    public init()
    {}

    /// The currently selected open file, or `nil`.
    public var selectedFile: OpenFile?
    {
        self.files.first { $0.id == self.selectedFileID }
    }

    /// Opens the given URLs, appending one ``OpenFile`` per URL. If nothing was
    /// selected, the first newly opened file becomes the selection; an existing
    /// selection is preserved.
    ///
    /// - Parameter urls: The file URLs to open.
    public func open( urls: [ URL ] )
    {
        let newFiles = urls.map { OpenFile( url: $0 ) }

        guard newFiles.isEmpty == false
        else
        {
            return
        }

        self.files.append( contentsOf: newFiles )

        if self.selectedFileID == nil
        {
            self.selectedFileID = newFiles.first?.id
        }
    }

    /// Closes the given file. If it was selected, selection moves to the nearest
    /// remaining file (preferring the previous one), or to `nil` when none
    /// remain.
    ///
    /// - Parameter file: The file to close.
    public func close( _ file: OpenFile )
    {
        guard let index = self.files.firstIndex( where: { $0.id == file.id } )
        else
        {
            return
        }

        let wasSelected = self.selectedFileID == file.id

        self.files.remove( at: index )

        if wasSelected
        {
            let fallback = self.files[ safe: index ] ?? self.files[ safe: index - 1 ] ?? self.files.first

            self.selectedFileID = fallback?.id
        }
    }
}

private extension Array
{
    /// Returns the element at `index`, or `nil` when out of bounds.
    subscript( safe index: Int ) -> Element?
    {
        indices.contains( index ) ? self[ index ] : nil
    }
}
