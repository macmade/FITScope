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

import SwiftAstro

/// The SF Symbol depicting each lunar phase.
///
/// This lives app-side rather than in SwiftAstro: the phase computation is a
/// reusable library concern, but the choice of SF Symbol is an Apple-platform
/// presentation detail, so the library stays UI-free.
extension MoonPhase.Phase
{
    /// The name of the SF Symbol depicting this phase.
    var systemImageName: String
    {
        switch self
        {
            case .newMoon:        return "moonphase.new.moon"
            case .waxingCrescent: return "moonphase.waxing.crescent"
            case .firstQuarter:   return "moonphase.first.quarter"
            case .waxingGibbous:  return "moonphase.waxing.gibbous"
            case .fullMoon:       return "moonphase.full.moon"
            case .waningGibbous:  return "moonphase.waning.gibbous"
            case .lastQuarter:    return "moonphase.last.quarter"
            case .waningCrescent: return "moonphase.waning.crescent"

            // `MoonPhase.Phase` is a non-frozen enum in another module, so a
            // future case must be handled; fall back to the generic moon symbol.
            @unknown default: return "moon"
        }
    }
}
