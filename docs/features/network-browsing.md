# Network Browsing Feature Documentation

## Overview

Network browsing enables access to files over FTP, SMB, and WebDAV protocols. Supports multiple platforms via custom services and plugins.

## Key Files & Entry Points

- services*network_browsing*\*
- ui*screens_network_browsing*\*

## Architecture & Integration

- Custom Dart services for each protocol
- UI screens for browsing and authentication
- Platform-specific helpers for native integration

## Technical Debt & Known Issues

- Legacy SMB/FTP code may lack full test coverage
- Platform-specific quirks

## Workarounds & Gotchas

- Manual setup required for some plugins
- Native integration may behave inconsistently

## Testing

- Limited integration tests
- Manual testing required for each platform

## Success Criteria

- Reliable browsing across supported protocols
- Consistent behavior on all platforms

## Protocol Services

- FTP, SMB, WebDAV services trong `services/network_browsing/`
- Tối ưu hóa SMB và native bindings cho hiệu năng

## Network Discovery

- Quét mạng tự động (`services/network_browsing/network_discovery_service.dart`)
- Registry cho các dịch vụ khả dụng (`services/network_browsing/network_service_registry.dart`)

## Authentication & Credentials

- Lưu trữ thông tin đăng nhập an toàn (`models/database/network_credentials.dart`)
- UI dialogs cho đăng nhập và xác thực

## Error Handling & Logging

- Tất cả thao tác mạng đều được ghi log
- Lỗi (ví dụ: kết nối thất bại, từ chối quyền) được hiển thị trên UI
- Tham khảo `logging.md` để xử lý sự cố

## Performance Optimization

- Prefetching, caching, và tối ưu hóa SMB chunk reading
- Sửa lỗi đặc thù từng nền tảng

## UI Components

- Màn hình duyệt mạng, dialogs, widgets
- Vị trí: `ui/screens/network_browsing/`, `ui/widgets/`

## Best Practices

- Kiểm thử duyệt mạng trên tất cả nền tảng hỗ trợ
- Theo dõi log để phát hiện lỗi mạng và xác thực

## Testing

- Unit test cho các dịch vụ protocol và discovery
- Kiểm thử thủ công cho UI và các trường hợp đặc biệt
