package com.example.prop

import android.graphics.Path

object SvgPathParser {

    fun parse(pathData: String): Path {
        val path = Path()
        val tokens = tokenize(pathData)
        var index = 0

        var currentX = 0f
        var currentY = 0f
        var startX = 0f
        var startY = 0f
        var lastControlX = 0f
        var lastControlY = 0f
        var lastCommand = ' '

        fun nextFloat(): Float {
            if (index >= tokens.size) return 0f
            return tokens[index++].toFloatOrNull() ?: 0f
        }

        fun hasNumber(): Boolean {
            return index < tokens.size && tokens[index][0].let { it.isDigit() || it == '-' || it == '+' || it == '.' }
        }

        while (index < tokens.size) {
            val token = tokens[index]
            val command = if (token.length == 1 && token[0].isLetter()) {
                index++
                token[0]
            } else {
                // تكرار ضمني لآخر أمر (مثلاً بعد M تأتي إحداثيات L ضمنية)
                when (lastCommand) {
                    'M' -> 'L'
                    'm' -> 'l'
                    else -> lastCommand
                }
            }

            when (command) {
                'M', 'm' -> {
                    val x = nextFloat()
                    val y = nextFloat()
                    if (command == 'm') {
                        currentX += x
                        currentY += y
                    } else {
                        currentX = x
                        currentY = y
                    }
                    path.moveTo(currentX, currentY)
                    startX = currentX
                    startY = currentY
                    lastControlX = currentX
                    lastControlY = currentY
                }

                'L', 'l' -> {
                    while (hasNumber()) {
                        val x = nextFloat()
                        val y = nextFloat()
                        if (command == 'l') {
                            currentX += x
                            currentY += y
                        } else {
                            currentX = x
                            currentY = y
                        }
                        path.lineTo(currentX, currentY)
                    }
                    lastControlX = currentX
                    lastControlY = currentY
                }

                'H', 'h' -> {
                    while (hasNumber()) {
                        val x = nextFloat()
                        currentX = if (command == 'h') currentX + x else x
                        path.lineTo(currentX, currentY)
                    }
                    lastControlX = currentX
                    lastControlY = currentY
                }

                'V', 'v' -> {
                    while (hasNumber()) {
                        val y = nextFloat()
                        currentY = if (command == 'v') currentY + y else y
                        path.lineTo(currentX, currentY)
                    }
                    lastControlX = currentX
                    lastControlY = currentY
                }

                'C', 'c' -> {
                    while (hasNumber()) {
                        var x1 = nextFloat()
                        var y1 = nextFloat()
                        var x2 = nextFloat()
                        var y2 = nextFloat()
                        var x = nextFloat()
                        var y = nextFloat()
                        if (command == 'c') {
                            x1 += currentX; y1 += currentY
                            x2 += currentX; y2 += currentY
                            x += currentX; y += currentY
                        }
                        path.cubicTo(x1, y1, x2, y2, x, y)
                        lastControlX = x2
                        lastControlY = y2
                        currentX = x
                        currentY = y
                    }
                }

                'S', 's' -> {
                    while (hasNumber()) {
                        val x1 = if (lastCommand in listOf('C', 'c', 'S', 's')) 2 * currentX - lastControlX else currentX
                        val y1 = if (lastCommand in listOf('C', 'c', 'S', 's')) 2 * currentY - lastControlY else currentY
                        var x2 = nextFloat()
                        var y2 = nextFloat()
                        var x = nextFloat()
                        var y = nextFloat()
                        if (command == 's') {
                            x2 += currentX; y2 += currentY
                            x += currentX; y += currentY
                        }
                        path.cubicTo(x1, y1, x2, y2, x, y)
                        lastControlX = x2
                        lastControlY = y2
                        currentX = x
                        currentY = y
                    }
                }

                'Q', 'q' -> {
                    while (hasNumber()) {
                        var x1 = nextFloat()
                        var y1 = nextFloat()
                        var x = nextFloat()
                        var y = nextFloat()
                        if (command == 'q') {
                            x1 += currentX; y1 += currentY
                            x += currentX; y += currentY
                        }
                        path.quadTo(x1, y1, x, y)
                        lastControlX = x1
                        lastControlY = y1
                        currentX = x
                        currentY = y
                    }
                }

                'T', 't' -> {
                    while (hasNumber()) {
                        val x1 = if (lastCommand in listOf('Q', 'q', 'T', 't')) 2 * currentX - lastControlX else currentX
                        val y1 = if (lastCommand in listOf('Q', 'q', 'T', 't')) 2 * currentY - lastControlY else currentY
                        var x = nextFloat()
                        var y = nextFloat()
                        if (command == 't') {
                            x += currentX; y += currentY
                        }
                        path.quadTo(x1, y1, x, y)
                        lastControlX = x1
                        lastControlY = y1
                        currentX = x
                        currentY = y
                    }
                }

                'Z', 'z' -> {
                    path.close()
                    currentX = startX
                    currentY = startY
                    lastControlX = currentX
                    lastControlY = currentY
                }
            }
            lastCommand = command
        }
        return path
    }

    private fun tokenize(data: String): List<String> {
        val result = ArrayList<String>()
        val sb = StringBuilder()
        var i = 0
        while (i < data.length) {
            val c = data[i]
            when {
                c.isLetter() && c != 'e' && c != 'E' -> {
                    if (sb.isNotEmpty()) {
                        result.add(sb.toString())
                        sb.clear()
                    }
                    result.add(c.toString())
                }
                c == ',' || c.isWhitespace() -> {
                    if (sb.isNotEmpty()) {
                        result.add(sb.toString())
                        sb.clear()
                    }
                }
                (c == '-' || c == '+') && sb.isNotEmpty() && sb.last() != 'e' && sb.last() != 'E' -> {
                    result.add(sb.toString())
                    sb.clear()
                    sb.append(c)
                }
                c == '.' && sb.contains('.') -> {
                    result.add(sb.toString())
                    sb.clear()
                    sb.append(c)
                }
                else -> sb.append(c)
            }
            i++
        }
        if (sb.isNotEmpty()) result.add(sb.toString())
        return result
    }
}