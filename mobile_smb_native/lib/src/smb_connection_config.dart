/// Configuration for SMB connection
class SmbConnectionConfig {
  /// SMB server hostname or IP address
  final String host;
  
  /// SMB server port (default: 445)
  final int port;
  
  /// Username for authentication
  final String username;
  
  /// Password for authentication
  final String password;
  
  /// Domain name (optional)
  final String? domain;
  
  /// Share name to connect to
  final String? shareName;
  
  /// Connection timeout in milliseconds
  final int timeoutMs;
  
  /// SMB protocol version (1, 2, or 3)
  final int smbVersion;

  const SmbConnectionConfig({
    required this.host,
    this.port = 445,
    required this.username,
    required this.password,
    this.domain,
    this.shareName,
    this.timeoutMs = 30000,
    this.smbVersion = 2,
  });

  /// Creates an SmbConnectionConfig from a map
  factory SmbConnectionConfig.fromMap(Map<String, dynamic> map) {
    return SmbConnectionConfig(
      host: map['host'] as String,
      port: map['port'] as int? ?? 445,
      username: map['username'] as String,
      password: map['password'] as String,
      domain: map['domain'] as String?,
      shareName: map['shareName'] as String?,
      timeoutMs: map['timeoutMs'] as int? ?? 30000,
      smbVersion: map['smbVersion'] as int? ?? 2,
    );
  }

  /// Converts this config to a map
  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'domain': domain,
      'shareName': shareName,
      'timeoutMs': timeoutMs,
      'smbVersion': smbVersion,
    };
  }

  /// Creates a copy of this config with updated values
  SmbConnectionConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? domain,
    String? shareName,
    int? timeoutMs,
    int? smbVersion,
  }) {
    return SmbConnectionConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      domain: domain ?? this.domain,
      shareName: shareName ?? this.shareName,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      smbVersion: smbVersion ?? this.smbVersion,
    );
  }

  @override
  String toString() {
    return 'SmbConnectionConfig(host: $host, port: $port, username: $username, domain: $domain, shareName: $shareName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmbConnectionConfig &&
        other.host == host &&
        other.port == port &&
        other.username == username &&
        other.password == password &&
        other.domain == domain &&
        other.shareName == shareName;
  }

  @override
  int get hashCode {
    return host.hashCode ^
        port.hashCode ^
        username.hashCode ^
        password.hashCode ^
        (domain?.hashCode ?? 0) ^
        (shareName?.hashCode ?? 0);
  }
}