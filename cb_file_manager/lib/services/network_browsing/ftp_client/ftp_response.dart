/// Represents a response from an FTP server
class FtpResponse {
  /// The numeric response code (e.g., 220, 331, 230)
  final int code;

  /// The response message
  final String message;

  FtpResponse(this.code, this.message);

  /// Parses an FTP server response string into an FtpResponse object
  static FtpResponse parse(String response) {
    // Handle multi-line responses (not implemented in this basic version)
    final responseLine = response.trim();

    // Parse response code (first 3 digits) and message
    if (responseLine.length >= 3) {
      try {
        final code = int.parse(responseLine.substring(0, 3));
        final message = responseLine.substring(3).trim();
        return FtpResponse(code, message);
      } catch (e) {
        // If parsing fails, return an error response
        return FtpResponse(500, 'Failed to parse response: $responseLine');
      }
    } else {
      // Invalid response format
      return FtpResponse(500, 'Invalid response format: $responseLine');
    }
  }

  /// Returns true if the response indicates success (codes 2xx)
  bool get isSuccess => code >= 200 && code < 300;

  /// Returns true if the response indicates an error (codes 4xx, 5xx)
  bool get isError => code >= 400 && code < 600;

  /// Returns true if the response indicates more information is needed (codes 3xx)
  bool get needsMoreInfo => code >= 300 && code < 400;

  @override
  String toString() => '$code $message';
}
