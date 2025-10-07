/// Utility functions for safe URI operations
class UriUtils {
  /// Safely decode a URI component with fallback to original string
  static String safeDecodeComponent(String encoded) {
    try {
      return Uri.decodeComponent(encoded);
    } catch (e) {
      // If decoding fails, return the original string
      return encoded;
    }
  }

  /// Safely encode a URI component
  static String safeEncodeComponent(String decoded) {
    try {
      return Uri.encodeComponent(decoded);
    } catch (e) {
      // If encoding fails, return the original string
      return decoded;
    }
  }
}
