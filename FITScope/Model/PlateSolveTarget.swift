/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
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

import Foundation

/// Identifies a single frame of an open file as the subject of a plate solve.
///
/// Plate solving is per-frame: a multi-image file's frames are distinct images,
/// each independently solvable with its own result. This value keys the
/// ``AppModel``'s plate-solve sessions and the plate-solve results `WindowGroup`
/// (so it must stay `Codable`/`Hashable`), pairing the file's identifier with the
/// zero-based index of the frame within its ``OpenFile/frames`` list.
public struct PlateSolveTarget: Codable, Hashable, Sendable
{
    /// The identifier of the file the frame belongs to.
    public let fileID: OpenFile.ID

    /// The zero-based index of the frame within the file's ``OpenFile/frames``.
    public let frameIndex: Int

    /// Creates a target for a specific frame of a file.
    ///
    /// - Parameters:
    ///   - fileID:     The owning file's identifier.
    ///   - frameIndex: The zero-based frame index within the file.
    public init( fileID: OpenFile.ID, frameIndex: Int )
    {
        self.fileID     = fileID
        self.frameIndex = frameIndex
    }
}
