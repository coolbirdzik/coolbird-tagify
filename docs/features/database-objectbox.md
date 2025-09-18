# Database ObjectBox Feature Documentation

## Overview

ObjectBox is used for high-performance local database storage in cb_file_manager. It stores tags, user preferences, file metadata, and supports fast queries and batch updates.

## ObjectBox Models

- Tag, user preference, file metadata models in `models/objectbox/`
- Extensible for new data types

## Database Provider

- Access via `models/database/database_provider.dart`, `models/objectbox/objectbox_database_provider.dart`
- Transaction management for data integrity

## Error Handling & Logging

- All database operations are logged
- Errors (e.g., failed transactions, data corruption) are surfaced in the UI
- Refer to `logging.md` for troubleshooting

## Performance Optimization

- Indexing and caching for fast queries
- Batch updates optimized for large data sets

## Best Practices

- Ensure ObjectBox is properly initialized before use
- Regularly backup database files
- Monitor logs for database errors

## Testing

- Unit tests for models and providers
- Manual testing for data integrity and edge cases


## Success Criteria

- Reliable data storage and retrieval
- No data loss or corruption
- Fast query and update performance

## Media & Video Player Integration

ObjectBox không chỉ lưu trữ metadata cho file mà còn hỗ trợ lưu thông tin liên quan đến media, phục vụ cho các tính năng video/audio player.

- Lưu trạng thái phát (playback position, last played, bookmarks) cho từng file media
- Tích hợp với các player như `media_kit`, `flutter_vlc_player`, và các widget custom
- Metadata media được truy vấn nhanh để hiển thị thumbnail, thời lượng, trạng thái phát gần nhất
- Hỗ trợ đồng bộ trạng thái phát giữa các thiết bị (nếu có backend)

## Video Player Components

- Widget phát video/audio sử dụng dữ liệu từ ObjectBox
- Lưu lịch sử phát, trạng thái pause/resume, và các thông tin liên quan
- Tích hợp với UI: hiển thị thumbnail, preview, và các nút điều khiển
- Các file chính: `helpers/media/`, `ui/widgets/lazy_video_thumbnail.dart`, `ui/components/streaming/`, `services/streaming/streaming_service_manager.dart`

## Best Practices for Media Data

- Luôn cập nhật trạng thái phát vào database khi pause/stop
- Sử dụng transaction khi cập nhật metadata media để tránh lỗi ghi đồng thời
- Đảm bảo đồng bộ dữ liệu khi phát trên nhiều thiết bị
