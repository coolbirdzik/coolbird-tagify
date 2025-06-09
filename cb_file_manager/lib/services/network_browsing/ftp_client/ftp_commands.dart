/// Helper class providing standard FTP commands
class FtpCommands {
  /// USER command - specifies the user for authentication
  static String user(String username) => 'USER $username';

  /// PASS command - specifies the password for authentication
  static String pass(String password) => 'PASS $password';

  /// PWD command - prints working directory
  static String pwd() => 'PWD';

  /// CWD command - changes working directory
  static String cwd(String path) => 'CWD $path';

  /// CDUP command - changes to parent directory
  static String cdup() => 'CDUP';

  /// QUIT command - terminates the connection
  static String quit() => 'QUIT';

  /// PORT command - specifies data connection parameters for active mode
  static String port(String hostPort) => 'PORT $hostPort';

  /// PASV command - enters passive mode
  static String pasv() => 'PASV';

  /// TYPE command - sets the transfer mode
  /// A: ASCII mode
  /// I: Binary mode (Image)
  /// E: EBCDIC mode
  static String type(String mode) => 'TYPE $mode';

  /// RETR command - retrieves a file from the server
  static String retr(String path) => 'RETR $path';

  /// STOR command - stores a file on the server
  static String stor(String path) => 'STOR $path';

  /// LIST command - lists directory contents
  static String list([String? path]) => path != null ? 'LIST $path' : 'LIST';

  /// NLST command - lists directory names only
  static String nlst([String? path]) => path != null ? 'NLST $path' : 'NLST';

  /// DELE command - deletes a file on the server
  static String dele(String path) => 'DELE $path';

  /// MKD command - creates a directory on the server
  static String mkd(String path) => 'MKD $path';

  /// RMD command - removes a directory on the server
  static String rmd(String path) => 'RMD $path';

  /// RNFR command - specifies rename-from filename
  static String rnfr(String path) => 'RNFR $path';

  /// RNTO command - specifies rename-to filename
  static String rnto(String newName) => 'RNTO $newName';

  /// SITE command - sends site-specific commands to remote server
  static String site(String command) => 'SITE $command';

  /// SYST command - returns system type
  static String syst() => 'SYST';

  /// STAT command - returns status information
  static String stat([String? path]) => path != null ? 'STAT $path' : 'STAT';

  /// HELP command - returns help information
  static String help([String? command]) =>
      command != null ? 'HELP $command' : 'HELP';

  /// No-operation command to keep connection alive
  static String noop() => 'NOOP';

  /// FEAT command - gets the features supported by the server
  static String feat() => 'FEAT';

  /// OPTS command - sets options for a feature
  static String opts(String feature, String options) =>
      'OPTS $feature $options';

  /// SIZE command - gets the size of a file
  static String size(String path) => 'SIZE $path';

  /// MDTM command - gets the modification time of a file
  static String mdtm(String path) => 'MDTM $path';
}
