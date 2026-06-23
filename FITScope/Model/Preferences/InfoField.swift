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

/// A single value the Image Information panel can display.
///
/// `InfoField` is the shared vocabulary between the panel — which renders the
/// fields the user has enabled, in their chosen order — and the Preferences
/// editor that configures that selection. Each field maps to a display label
/// and (in ``ImageInformation``) to the header keyword(s) it reads.
///
/// The `rawValue` of each case is a stable identifier used to persist the user's
/// configuration, so cases must not be renamed once shipped. ``allCases`` is the
/// canonical default order, leading with the geometry fields that head the
/// panel's historical layout.
public enum InfoField: String, CaseIterable, Identifiable, Sendable
{
    case dimensions
    case bitDepth
    case channels
    case bayer
    case object
    case rightAscension
    case declination
    case date
    case exposure
    case filter
    case telescope
    case instrument
    case focalLength
    case gain
    case offset
    case sensorTemperature

    /// The field's stable identity, matching its persisted raw value.
    public var id: String { self.rawValue }

    /// The human-readable label shown beside the value in the panel and as the
    /// row title in the Preferences editor.
    public var label: String
    {
        switch self
        {
            case .dimensions:        return "Dimensions"
            case .bitDepth:          return "Bit Depth"
            case .channels:          return "Channels"
            case .bayer:             return "Bayer"
            case .object:            return "Object"
            case .rightAscension:    return "RA"
            case .declination:       return "Dec"
            case .date:              return "Date"
            case .exposure:          return "Exposure"
            case .filter:            return "Filter"
            case .telescope:         return "Telescope"
            case .instrument:        return "Instrument"
            case .focalLength:       return "Focal Length"
            case .gain:              return "Gain"
            case .offset:            return "Offset"
            case .sensorTemperature: return "Sensor Temp"
        }
    }

    /// The name of the SF Symbol shown beside the field in the panel and the
    /// Preferences editor. Every name is checked to resolve to a real symbol by
    /// `InfoFieldTests.everyFieldHasAResolvableSystemImage`.
    public var systemImageName: String
    {
        switch self
        {
            case .dimensions:        return "aspectratio"
            case .bitDepth:          return "circle.lefthalf.filled"
            case .channels:          return "camera.filters"
            case .bayer:             return "square.grid.2x2"
            case .object:            return "scope"
            case .rightAscension:    return "arrow.left.arrow.right"
            case .declination:       return "arrow.up.arrow.down"
            case .date:              return "calendar"
            case .exposure:          return "timer"
            case .filter:            return "line.3.horizontal.decrease.circle"
            case .telescope:         return "binoculars.fill"
            case .instrument:        return "camera"
            case .focalLength:       return "ruler"
            case .gain:              return "dial.medium"
            case .offset:            return "slider.horizontal.3"
            case .sensorTemperature: return "thermometer.medium"
        }
    }
}
