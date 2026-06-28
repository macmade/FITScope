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

/// A namespace for the decoded Astrometry.net API responses, one nested type per
/// endpoint. The shapes mirror the documented responses at
/// `https://astrometry.net/doc/net/api.html`, captured here so the client decodes
/// the real wire format. The wire uses the service's own field names.
enum AstrometryResponse
{
    /// The `login` response: a session key on success, or an error message.
    struct Login: Decodable
    {
        /// `success` when authenticated, otherwise typically `error`.
        let status: String

        /// The session key used by every subsequent request, present on success.
        let session: String?

        /// The service's error message, present on failure.
        let errorMessage: String?

        private enum CodingKeys: String, CodingKey
        {
            case status
            case session
            case errorMessage = "errormessage"
        }
    }

    /// The `upload` / `url_upload` response: the submission id on success.
    struct Upload: Decodable
    {
        /// `success` when accepted, otherwise typically `error`.
        let status: String

        /// The submission id to poll for the resulting job, present on success.
        let subid: Int?

        /// The service's error message, present on failure.
        let errorMessage: String?

        private enum CodingKeys: String, CodingKey
        {
            case status
            case subid
            case errorMessage = "errormessage"
        }
    }

    /// The `submissions/SUBID` response. The `jobs` array holds a `null`
    /// placeholder until a job is created, then the job id; the first non-null
    /// entry identifies the job to poll.
    struct Submission: Decodable
    {
        /// The submission's jobs; entries are `null` until the job exists.
        let jobs: [ Int? ]

        /// The first created job's id, or `nil` while still queued.
        var jobID: Int?
        {
            self.jobs.compactMap { $0 }.first
        }
    }

    /// The `jobs/JOBID` response: the solve status (`solving`, `success`, or
    /// `failure`).
    struct Job: Decodable
    {
        /// The job's current status.
        let status: String
    }

    /// The `jobs/JOBID/objects_in_field` response: the catalogue objects
    /// identified in the solved field.
    struct ObjectsInField: Decodable
    {
        /// The identified objects' names.
        let objects: [ String ]

        private enum CodingKeys: String, CodingKey
        {
            case objects = "objects_in_field"
        }
    }
}
