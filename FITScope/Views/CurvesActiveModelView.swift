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

import SwiftUI

/// Bridges the frontmost window's model to the Curves editor, observing it so the
/// editor follows the window's selection.
struct CurvesActiveModelView: View
{
    /// The frontmost window's model, observed so a selection change re-targets
    /// the editor.
    @ObservedObject var model: WindowModel

    /// The view's content.
    var body: some View
    {
        if let image = self.model.selectedFile?.image, image.renderer.result != nil
        {
            // Keyed on the image's identity so switching files recreates the
            // editor, reseeding its control points from the new file's curve.
            CurvesEditorView( image: image )
                .id( ObjectIdentifier( image ) )
        }
        else
        {
            CurvesUnavailableView()
        }
    }
}
