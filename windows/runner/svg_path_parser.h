#ifndef RUNNER_SVG_PATH_PARSER_H_
#define RUNNER_SVG_PATH_PARSER_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <d2d1.h>

#include <string>
#include <vector>

struct SvgContour
{
    std::vector<D2D1_POINT_2F> points;
    std::vector<float> seg_lengths;
    float total_length = 0.0f;
};

class SvgPathParser
{
public:
    static std::vector<SvgContour> LoadFromSvgFile(
        const std::wstring &file_path,
        float target_width,
        float target_height,
        float stroke_width);

private:
    static std::string ReadFileAsUtf8(const std::wstring &file_path);
    static std::vector<std::string> ExtractPathStringsFromXml(const std::string &xml_content);
    static void ParsePathDataIntoContours(
        const std::string &path_data,
        std::vector<SvgContour> &out_contours);
    static std::vector<std::string> Tokenize(const std::string &data);
};

#endif // RUNNER_SVG_PATH_PARSER_H_