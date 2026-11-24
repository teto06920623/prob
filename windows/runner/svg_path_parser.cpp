#include "svg_path_parser.h"

#include <windows.h>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <fstream>
#include <vector>

std::string SvgPathParser::ReadFileAsUtf8(const std::wstring &file_path)
{
    std::ifstream file(file_path.c_str(), std::ios::binary);
    if (!file.is_open())
        return {};

    std::string raw((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    if (raw.empty())
        return {};

    if (raw.size() >= 3 &&
        static_cast<unsigned char>(raw[0]) == 0xEF &&
        static_cast<unsigned char>(raw[1]) == 0xBB &&
        static_cast<unsigned char>(raw[2]) == 0xBF)
    {
        return raw.substr(3);
    }

    bool has_le_bom = (raw.size() >= 2 &&
                       static_cast<unsigned char>(raw[0]) == 0xFF &&
                       static_cast<unsigned char>(raw[1]) == 0xFE);
    bool looks_le = (raw.size() >= 4 && raw[1] == '\0' && raw[3] == '\0');
    if (has_le_bom || looks_le)
    {
        size_t offset = has_le_bom ? 2 : 0;
        size_t wlen = (raw.size() - offset) / sizeof(wchar_t);
        const auto *wptr = reinterpret_cast<const wchar_t *>(raw.data() + offset);
        int u8len = WideCharToMultiByte(CP_UTF8, 0, wptr, static_cast<int>(wlen), nullptr, 0, nullptr, nullptr);
        if (u8len <= 0)
            return {};
        std::string out(static_cast<size_t>(u8len), '\0');
        WideCharToMultiByte(CP_UTF8, 0, wptr, static_cast<int>(wlen), out.data(), u8len, nullptr, nullptr);
        return out;
    }

    return raw;
}

std::vector<SvgContour> SvgPathParser::LoadFromSvgFile(
    const std::wstring &file_path,
    float target_width,
    float target_height,
    float stroke_width)
{
    std::vector<SvgContour> contours;
    std::string xml_content = ReadFileAsUtf8(file_path);
    if (xml_content.empty())
        return contours;

    std::vector<std::string> path_strings = ExtractPathStringsFromXml(xml_content);
    for (const auto &d : path_strings)
    {
        ParsePathDataIntoContours(d, contours);
    }

    if (contours.empty())
        return contours;

    float min_x = 1e9f, min_y = 1e9f, max_x = -1e9f, max_y = -1e9f;
    for (const auto &c : contours)
    {
        for (const auto &pt : c.points)
        {
            min_x = (std::min)(min_x, pt.x);
            min_y = (std::min)(min_y, pt.y);
            max_x = (std::max)(max_x, pt.x);
            max_y = (std::max)(max_y, pt.y);
        }
    }

    float raw_w = max_x - min_x;
    float raw_h = max_y - min_y;
    if (raw_w <= 0.0f || raw_h <= 0.0f)
    {
        contours.clear();
        return contours;
    }

    float padding = stroke_width * 2.5f;
    float avail_w = (std::max)(10.0f, target_width - padding * 2.0f);
    float avail_h = (std::max)(10.0f, target_height - padding * 2.0f);
    float scale = (std::min)(avail_w / raw_w, avail_h / raw_h);

    float cx = (min_x + max_x) * 0.5f;
    float cy = (min_y + max_y) * 0.5f;

    for (auto &c : contours)
    {
        c.seg_lengths.clear();
        c.total_length = 0.0f;
        for (auto &pt : c.points)
        {
            pt.x = (pt.x - cx) * scale + target_width * 0.5f;
            pt.y = (pt.y - cy) * scale + target_height * 0.5f;
        }
        for (size_t i = 1; i < c.points.size(); ++i)
        {
            float dx = c.points[i].x - c.points[i - 1].x;
            float dy = c.points[i].y - c.points[i - 1].y;
            float len = std::hypot(dx, dy);
            c.seg_lengths.push_back(len);
            c.total_length += len;
        }
    }

    return contours;
}

std::vector<std::string> SvgPathParser::ExtractPathStringsFromXml(
    const std::string &xml_content)
{
    std::vector<std::string> paths;
    size_t pos = 0;

    while ((pos = xml_content.find("<path", pos)) != std::string::npos)
    {
        size_t tag_end = xml_content.find('>', pos);
        if (tag_end == std::string::npos)
            break;

        std::string tag = xml_content.substr(pos, tag_end - pos + 1);
        size_t d_pos = 0;
        while ((d_pos = tag.find('d', d_pos)) != std::string::npos)
        {
            bool valid_prefix = (d_pos > 0 && (std::isspace(static_cast<unsigned char>(tag[d_pos - 1])) ||
                                               tag[d_pos - 1] == '<'));
            size_t eq_pos = d_pos + 1;
            while (eq_pos < tag.size() && std::isspace(static_cast<unsigned char>(tag[eq_pos])))
            {
                ++eq_pos;
            }

            if (valid_prefix && eq_pos < tag.size() && tag[eq_pos] == '=')
            {
                size_t quote_start = eq_pos + 1;
                while (quote_start < tag.size() &&
                       std::isspace(static_cast<unsigned char>(tag[quote_start])))
                {
                    ++quote_start;
                }
                if (quote_start < tag.size() && (tag[quote_start] == '"' || tag[quote_start] == '\''))
                {
                    char quote_char = tag[quote_start];
                    size_t quote_end = tag.find(quote_char, quote_start + 1);
                    if (quote_end != std::string::npos)
                    {
                        std::string d_val = tag.substr(quote_start + 1, quote_end - quote_start - 1);
                        if (!d_val.empty())
                        {
                            paths.push_back(std::move(d_val));
                        }
                        break;
                    }
                }
            }
            ++d_pos;
        }
        pos = tag_end + 1;
    }
    return paths;
}

void SvgPathParser::ParsePathDataIntoContours(
    const std::string &path_data,
    std::vector<SvgContour> &out_contours)
{
    std::vector<std::string> tokens = Tokenize(path_data);
    size_t index = 0;

    float current_x = 0.0f;
    float current_y = 0.0f;
    float start_x = 0.0f;
    float start_y = 0.0f;
    float last_ctrl_x = 0.0f;
    float last_ctrl_y = 0.0f;
    char last_cmd = ' ';
    SvgContour current;

    auto flush = [&]()
    {
        if (current.points.size() >= 2)
        {
            out_contours.push_back(std::move(current));
        }
        current = SvgContour{};
    };

    auto has_number = [&]() -> bool
    {
        if (index >= tokens.size() || tokens[index].empty())
            return false;
        char c = tokens[index][0];
        return std::isdigit(static_cast<unsigned char>(c)) || c == '-' || c == '+' || c == '.';
    };

    auto next_float = [&]() -> float
    {
        if (index >= tokens.size())
            return 0.0f;
        try
        {
            return std::stof(tokens[index++]);
        }
        catch (...)
        {
            return 0.0f;
        }
    };

    auto add_quad = [&](float x1, float y1, float x2, float y2)
    {
        float x0 = current_x;
        float y0 = current_y;
        constexpr int kSteps = 14;
        for (int i = 1; i <= kSteps; ++i)
        {
            float t = static_cast<float>(i) / static_cast<float>(kSteps);
            float inv = 1.0f - t;
            float px = inv * inv * x0 + 2.0f * inv * t * x1 + t * t * x2;
            float py = inv * inv * y0 + 2.0f * inv * t * y1 + t * t * y2;
            current.points.push_back(D2D1::Point2F(px, py));
        }
    };

    auto add_cubic = [&](float x1, float y1, float x2, float y2, float x3, float y3)
    {
        float x0 = current_x;
        float y0 = current_y;
        constexpr int kSteps = 18;
        for (int i = 1; i <= kSteps; ++i)
        {
            float t = static_cast<float>(i) / static_cast<float>(kSteps);
            float inv = 1.0f - t;
            float px = inv * inv * inv * x0 + 3.0f * inv * inv * t * x1 +
                       3.0f * inv * t * t * x2 + t * t * t * x3;
            float py = inv * inv * inv * y0 + 3.0f * inv * inv * t * y1 +
                       3.0f * inv * t * t * y2 + t * t * t * y3;
            current.points.push_back(D2D1::Point2F(px, py));
        }
    };

    while (index < tokens.size())
    {
        const std::string &tok = tokens[index];
        char cmd = ' ';
        if (tok.size() == 1 && std::isalpha(static_cast<unsigned char>(tok[0])))
        {
            cmd = tok[0];
            ++index;
        }
        else
        {
            if (last_cmd == 'M')
                cmd = 'L';
            else if (last_cmd == 'm')
                cmd = 'l';
            else
                cmd = last_cmd;
        }

        switch (cmd)
        {
        case 'M':
        case 'm':
        {
            float x = next_float();
            float y = next_float();
            if (cmd == 'm')
            {
                current_x += x;
                current_y += y;
            }
            else
            {
                current_x = x;
                current_y = y;
            }
            flush();
            current.points.push_back(D2D1::Point2F(current_x, current_y));
            start_x = last_ctrl_x = current_x;
            start_y = last_ctrl_y = current_y;
            break;
        }

        case 'L':
        case 'l':
        {
            while (has_number())
            {
                float x = next_float();
                float y = next_float();
                if (cmd == 'l')
                {
                    current_x += x;
                    current_y += y;
                }
                else
                {
                    current_x = x;
                    current_y = y;
                }
                current.points.push_back(D2D1::Point2F(current_x, current_y));
            }
            last_ctrl_x = current_x;
            last_ctrl_y = current_y;
            break;
        }

        case 'H':
        case 'h':
        {
            while (has_number())
            {
                float x = next_float();
                current_x = (cmd == 'h') ? (current_x + x) : x;
                current.points.push_back(D2D1::Point2F(current_x, current_y));
            }
            last_ctrl_x = current_x;
            last_ctrl_y = current_y;
            break;
        }

        case 'V':
        case 'v':
        {
            while (has_number())
            {
                float y = next_float();
                current_y = (cmd == 'v') ? (current_y + y) : y;
                current.points.push_back(D2D1::Point2F(current_x, current_y));
            }
            last_ctrl_x = current_x;
            last_ctrl_y = current_y;
            break;
        }

        case 'Q':
        case 'q':
        {
            while (has_number())
            {
                float x1 = next_float();
                float y1 = next_float();
                float x = next_float();
                float y = next_float();
                if (cmd == 'q')
                {
                    x1 += current_x;
                    y1 += current_y;
                    x += current_x;
                    y += current_y;
                }
                add_quad(x1, y1, x, y);
                last_ctrl_x = x1;
                last_ctrl_y = y1;
                current_x = x;
                current_y = y;
            }
            break;
        }

        case 'T':
        case 't':
        {
            while (has_number())
            {
                bool prev_quad = (last_cmd == 'Q' || last_cmd == 'q' || last_cmd == 'T' || last_cmd == 't');
                float x1 = prev_quad ? (2.0f * current_x - last_ctrl_x) : current_x;
                float y1 = prev_quad ? (2.0f * current_y - last_ctrl_y) : current_y;
                float x = next_float();
                float y = next_float();
                if (cmd == 't')
                {
                    x += current_x;
                    y += current_y;
                }
                add_quad(x1, y1, x, y);
                last_ctrl_x = x1;
                last_ctrl_y = y1;
                current_x = x;
                current_y = y;
            }
            break;
        }

        case 'C':
        case 'c':
        {
            while (has_number())
            {
                float x1 = next_float();
                float y1 = next_float();
                float x2 = next_float();
                float y2 = next_float();
                float x = next_float();
                float y = next_float();
                if (cmd == 'c')
                {
                    x1 += current_x;
                    y1 += current_y;
                    x2 += current_x;
                    y2 += current_y;
                    x += current_x;
                    y += current_y;
                }
                add_cubic(x1, y1, x2, y2, x, y);
                last_ctrl_x = x2;
                last_ctrl_y = y2;
                current_x = x;
                current_y = y;
            }
            break;
        }

        case 'S':
        case 's':
        {
            while (has_number())
            {
                bool prev_cubic = (last_cmd == 'C' || last_cmd == 'c' || last_cmd == 'S' || last_cmd == 's');
                float x1 = prev_cubic ? (2.0f * current_x - last_ctrl_x) : current_x;
                float y1 = prev_cubic ? (2.0f * current_y - last_ctrl_y) : current_y;
                float x2 = next_float();
                float y2 = next_float();
                float x = next_float();
                float y = next_float();
                if (cmd == 's')
                {
                    x2 += current_x;
                    y2 += current_y;
                    x += current_x;
                    y += current_y;
                }
                add_cubic(x1, y1, x2, y2, x, y);
                last_ctrl_x = x2;
                last_ctrl_y = y2;
                current_x = x;
                current_y = y;
            }
            break;
        }

        case 'Z':
        case 'z':
        {
            if (!current.points.empty())
            {
                current.points.push_back(D2D1::Point2F(start_x, start_y));
            }
            flush();
            current_x = last_ctrl_x = start_x;
            current_y = last_ctrl_y = start_y;
            break;
        }

        default:
            while (has_number())
            {
                next_float();
            }
            break;
        }

        last_cmd = cmd;
    }

    flush();
}

std::vector<std::string> SvgPathParser::Tokenize(const std::string &data)
{
    std::vector<std::string> tokens;
    std::string sb;

    for (char c : data)
    {
        if (std::isalpha(static_cast<unsigned char>(c)) && c != 'e' && c != 'E')
        {
            if (!sb.empty())
            {
                tokens.push_back(sb);
                sb.clear();
            }
            tokens.emplace_back(1, c);
        }
        else if (c == ',' || std::isspace(static_cast<unsigned char>(c)))
        {
            if (!sb.empty())
            {
                tokens.push_back(sb);
                sb.clear();
            }
        }
        else if ((c == '-' || c == '+') && !sb.empty() && sb.back() != 'e' && sb.back() != 'E')
        {
            tokens.push_back(sb);
            sb.clear();
            sb.push_back(c);
        }
        else if (c == '.' && sb.find('.') != std::string::npos)
        {
            tokens.push_back(sb);
            sb.clear();
            sb.push_back(c);
        }
        else
        {
            sb.push_back(c);
        }
    }

    if (!sb.empty())
    {
        tokens.push_back(sb);
    }
    return tokens;
}