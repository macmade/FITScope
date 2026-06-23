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

/// The root of the single, app-wide Curves editor window.
///
/// Like ``LevelsWindowView``, this is a singleton scene that edits whichever
/// document window is frontmost, following the active model published by the
/// shared ``AppModel``. Its pieces live in their own files:
/// ``CurvesActiveModelView`` bridges the frontmost window's model,
/// ``CurvesEditorView`` is the editor, ``CurveEditorCanvas`` is the draggable
/// curve control, and ``CurvesUnavailableView`` is the no-image placeholder.
public struct CurvesWindowView: View
{
    /// The app-wide coordination object that tracks the frontmost window.
    @EnvironmentObject private var appModel: AppModel

    /// Creates the window root.
    public init()
    {}

    /// The view's content.
    public var body: some View
    {
        Group
        {
            if let model = self.appModel.activeModel
            {
                CurvesActiveModelView( model: model )
            }
            else
            {
                CurvesUnavailableView()
            }
        }
        .frame( minWidth: 360, minHeight: 520 )
    }
}
