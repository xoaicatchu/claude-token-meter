# Claude Token Meter

Một dòng chữ nhỏ, mờ, dính trên thanh tiêu đề cửa sổ Claude trên Windows, hiển thị **% hạn mức token đã dùng**, ví dụ `5h 14% · Tuần 65%`. 100% là hết. Số từ 80% chuyển vàng, từ 95% chuyển đỏ.

## Yêu cầu

- Windows (widget dùng PowerShell và WPF, có sẵn trên Windows).
- App Claude desktop hoặc Claude Code bản mới có hỗ trợ mod. Đã chạy trên engine 2.1.317. CLI 2.1.126 cài được nhưng không đọc được mod, cần cập nhật.
- Đăng nhập bằng gói trả phí (Pro, Max...). Dùng API key thì không có số hạn mức.

## Cài đặt

**Trong app Claude desktop (tab Code):**

1. Bấm dấu **+** cạnh ô nhập, chọn **Plugins**.
2. Chọn **Add marketplace**, nhập `xoaicatchu/claude-token-meter`.
3. Chọn **Add plugin**, chọn `token-meter`.

**Hoặc từ terminal:**

```bash
claude plugin install token-meter --marketplace xoaicatchu/claude-token-meter
```

Nếu được hỏi thêm marketplace thì trả lời `y`, rồi chọn phạm vi `user`.

Mở một phiên Claude mới, widget sẽ tự hiện trên thanh tiêu đề cửa sổ Claude. Nếu không có cửa sổ app Claude (chỉ dùng terminal), widget nằm ở góc trên bên phải màn hình.

## Cách dùng

- Widget đi theo cửa sổ Claude, thu nhỏ theo cửa sổ và không đè lên app khác.
- Rê chuột vào để widget rõ hẳn và xem giờ đặt lại.
- Chuột phải, chọn **Đóng** để tắt. Phiên Claude mới sẽ mở lại widget.

## Số cập nhật thế nào

Mod lấy số từ phiên Claude đang chạy và ghi vào `%USERPROFILE%\.claude\token-meter.json`. Widget đọc file đó 5 giây một lần.

- Số mới về sau mỗi phản hồi của Claude, và mod đọc lại 30 giây một lần.
- Không có phiên Claude nào chạy thì số đứng yên. Dòng nào đã qua giờ đặt lại sẽ hiện `—`.
- Chỉ có hạn mức 5 giờ và hạn mức tuần. Hạn mức riêng theo model không có trong nguồn số này.

Mod không gọi mạng và không đọc thông tin đăng nhập. Nó chỉ ghi file trên và mở widget.

## Gỡ cài đặt

Đóng widget, gỡ plugin `token-meter`, rồi xoá file `%USERPROFILE%\.claude\token-meter.json`.
