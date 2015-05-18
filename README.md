<a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=VNNFRTC6YP8ZL"><img alt="Donate to Logger" border="0" src="https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif"></a>

- [What is Logger?](#what-is-logger)
- [Documentation](#documentation)
- [Download](#download)
- [Change Log](#change-log)
- [License](#license)

#What is Logger?

[![Analytics](https://ga-beacon.appspot.com/UA-59573016-4/Logger/README.md?pixel)](https://github.com/igrigorik/ga-beacon)Logger is a PL/SQL logging and debugging framework. The goal of logger is to be as simple as possible to install and use. The primary use cases for this utility include:

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
In order to keep this page relatively small and for ease of use, the documentation has been moved to the [Logger Docs](docs). In there you you will find the following sections:
- [Installation](docs/Installation.md)
- [Logger API](docs/Logger API.md)
- [Plugins](docs/Plugins.md)
- [Best Practices](docs/Best Practices.md)
- [Development Guide](docs/Development Guide.md)
- [3rd Party Addons](docs/Addons.md)

#Download
It is recommended that you download a certified release (from the [releases](https://github.com/OraOpenSource/Logger/tree/master/releases) folder). The files in the current repository are for the next release and should be considered unstable.

#Change Log
The [Change Logs](docs/Change Logs.md) contain all the major updates for each release. Complete set of issues can be found on [Milestones](https://github.com/OraOpenSource/Logger/milestones?state=closed) page.

#History
Logger was originally created by [Tyler Muth](https://twitter.com/tmuth) and is now maintained by [OraOpenSource](http://www.oraopensource.com).

#License
This project is uses the [MIT license](LICENSE).
