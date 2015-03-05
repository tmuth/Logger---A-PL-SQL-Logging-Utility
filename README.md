- [What is Logger?](#what-is-logger)
- [Documentation](#documentation)
- [Download](#download)
- [Change Log](#change-log)
- [License](#license)

#What is Logger?

Logger is a PL/SQL logging and debugging framework. The goal of logger is to be as simple as possible to install and use. The primary use cases for this utility include:

* **Debugging**: It's often difficult to track down the source of an error without some form of debugging instrumentation. This is particularly true in multi-tier, stateless architectures such as Application Exp qress.
* **Error Logging**: While most experts agree that it's important not to mask errors, it's also nice to have a persistent record of them.
* **Timing: Logger** has a very simple timing framework built-in that makes it easy to benchmark sections of code.
* **Instrumentation**: Because it's easy to "turn-off" logger globally with virtually no performance impact, it's easy to get in the habit of leaving debug calls in production code. Now, when something does go wrong, you simply flip the switch and logger is enabled making it much quicker to debug errors.

##Feedback/Issues
Please submit any feedback, suggestions, or issues on the project's [issue page](https://github.com/oraopensource/logger/issues).

##Demo
```sql
exec logger.log('hello world');

select * from logger_logs;
-- This will display all the logged logs
```

See the [Logger API](docs/Logger API.md) documentation for complete set of procedures.

#Documentation
In order to keep this page relatively small and for ease of use, the documentation has been moved to the [Logger Wiki](../../wiki). In there you you will find the following sections:
- [Installation](../../wiki/Installation)
- [Logger API](../../wiki/Logger-API)
- [Best Practices](../../wiki/Best Practices)

#Download
It is recommended that you download a certified release (from the [releases](https://github.com/oraopensource/logger/tree/master/releases) folder). The files in the current repository are for the next release and should be considered unstable.

#Change Log
The [Change Log](../../wiki/Change Logs) page has moved to the [wiki page](../../wiki/Change Logs).


#License
-- TODO mdsouza: Change this
Copyright (c) 2013, Tyler D. Muth, tylermuth.wordpress.com
and contributors to the project at
https://github.com/oraopensource/logger
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
* Neither the name of Tyler D Muth, nor Oracle Corporation, nor the
  names of its contributors may be used to endorse or promote products
  derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
