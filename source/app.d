import raylib;
import std.algorithm;
import std.stdio;
import std.random;

void main() {
    auto map = MinesweeperMap();
    map.create(24, 20);

    SetConfigFlags(ConfigFlag.FLAG_MSAA_4X_HINT);
    InitWindow(800, 600, "minesweeper");
    while (!WindowShouldClose())
    {
        BeginDrawing();
        ClearBackground(Colors.BLACK);
        map.update();
        map.draw();
        EndDrawing();
    }
    CloseWindow();
}

struct MinesweeperMap {
    size_t   width, height;
    ushort[] tiles;
    ushort[] adjacency;
    bool     hasGameover = false;
    bool     firstClick  = true;

    void create (size_t x, size_t y, double bombPct = 0.2) {
        assert(x > 0 && y > 0);
        assert(bombPct > 0 && bombPct < 1);
        width = x; height = y;
        tiles.length = x * y;
        foreach (ref tile; tiles) { tile = 0; }
        size_t numBombs = cast(size_t)(x * y * bombPct).clamp(1, x * y);
        writefln("spawning %s bombs", numBombs);
        assert(tiles.length > 0);
        while (numBombs --> 0) {
            size_t index = uniform!"[]"(0UL, tiles.length - 1);
            if (tiles[index] & 0x2) { ++numBombs; }
            else { tiles[index] |= 0x2; }
        }
        updateAdjacency();
    }
    void restart () {
        hasGameover = false;
        firstClick = true;
        create(width, height);
    }
    void update () {
        if (hasGameover) {
            if (IsKeyPressed('R')) {
                restart();   
            }
            return;
        }
        int mouseX = GetMouseX(), mouseY = GetMouseY();
        int tileX  = (mouseX - 20) / 22, tileY = (mouseY - 20) / 22;
        if (tileX >= 0 && tileY >= 0 && tileX < width && tileY < height) {
            //writefln("mouseover tile %s,%s", tileX, tileY);
            size_t index = cast(size_t)(tileX + tileY * width);
            assert(index < tiles.length);

            if (IsMouseButtonPressed(1)) {
                ushort flag = 0x4;
                //writefln("toggle %s %s", mouseX, mouseY);
                tiles[index] = (tiles[index] & (~flag)) | (tiles[index] ^ flag);
            } else if (IsMouseButtonPressed(0) && !(tiles[index] & 0x4)) {
                //writefln("click: %s,%s %s", tileX, tileY, index);
                if (firstClick) {
                    firstClick = false;
                    tiles[index] &= ~0x2;
                    updateAdjacency();
                }
                if (tiles[index] & 0x2) {
                    gameover();
                } else {
                    floodFillMakeVisible(tileX, tileY);
                    updateAdjacency();
                }
            }
        }
    }
    void floodFillMakeVisible(int x, int y) {
        void floodfillRecurse(int x, int y) {
            if (x < 0 || x >= width || y < 0 || y >= height) return;
            if (tiles[x + y * width] & 0x12) return;
            tiles[x + y * width] |= 0x11;
            if (adjacency[x + y * width] > 0) return;
            floodfillRecurse(x - 1, y - 1);
            floodfillRecurse(x - 1, y);
            floodfillRecurse(x - 1, y + 1);
            floodfillRecurse(x, y + 1);
            floodfillRecurse(x + 1, y + 1);
            floodfillRecurse(x + 1, y);
            floodfillRecurse(x + 1, y - 1);
        }
        foreach (ref tile; tiles) { tile &= 0xf; }
        floodfillRecurse(x, y);
    }   

    void updateAdjacency () {
        adjacency.length = tiles.length;
        foreach (ref adj; adjacency) { adj = 0; }

        auto n = width * height;
        foreach (i, ref tile; tiles) {
            if (tile & 0x2) {
                int x = cast(int)(i % width), y = cast(int)(i / width);
                writefln("%s %s %s %s", i, x, y, adjacency.length);

                int adjFlags = 0;
                if (x > 0)          ++adjacency[i-1]; else adjFlags |= 0x1;
                if (x + 1 < width)  ++adjacency[i+1]; else adjFlags |= 0x2;

                if (y > 0)          ++adjacency[i-width]; else adjFlags |= 0x4;
                if (y + 1 < height) ++adjacency[i+width]; else adjFlags |= 0x8;

                if (!(adjFlags & (0x1 | 0x4))) ++adjacency[i-1-width];
                if (!(adjFlags & (0x1 | 0x8))) ++adjacency[i-1+width];
                if (!(adjFlags & (0x2 | 0x4))) ++adjacency[i+1-width];
                if (!(adjFlags & (0x2 | 0x8))) ++adjacency[i+1+width];
            }
        }
    }
    void gameover () {
        hasGameover = true;
        // make all bombs visible
        foreach (ref tile; tiles) { if (tile & 0x2) tile |= 0x1; }
    }
    void draw () {
        assert(width * height == tiles.length);
        int mouseX = GetMouseX(), mouseY = GetMouseY();
        foreach (y; 0 .. height) {
            foreach (x; 0 .. width) {
                int x0 = cast(int)x * 22 + 20,
                    y0 = cast(int)y * 22 + 20;
                int w = 21, h = 21;

                bool mouseover = !(
                    mouseX < x0 || mouseX > x0 + w ||
                    mouseY < y0 || mouseY > y0 + w
                );
                auto index = x + y * width;
                auto tile    = tiles[index];
                bool visible = (tile & 0x1) != 0;
                bool bomb    = (tile & 0x2) != 0;
                bool flag    = (tile & 0x4) != 0;

                DrawRectangle(x0, y0, 21, 21,
                    mouseover ? Color(200, 250, 200, 255) :
                    visible   ? Color(180, 180, 180, 255) :
                                Color(150, 150, 150, 255)                    
                );
                if (visible && bomb) {
                    DrawRectangle(x0 + 2, y0 + 2, 21 - 4, 21 - 4,
                        Color(10, 10, 10, 255));
                } else {
                    if (flag) {
                        DrawRectangle(x0 + 2, y0 + 2, 21 - 4, 21 - 4,
                            Color(100, 20, 20, 255));
                    }
                    if (visible && adjacency[index] > 0) {
                        immutable const(char)*[] text = [ "0\0", "1\0", "2\0", "3\0", "4\0", "5\0", "6\0", "7\0", "8\0", "9\0" ];
                        //immutable Color[] colors = [ Color(255,255,255,255), Color(100,255,100,255), Color(255,100,100,255), Color(100,100,255,255)
                        //]
                        Color color = Color(10,10,10,255);
                        auto  adj   = adjacency[index];
                        if (adj & 1) color.b += 100;
                        if (adj & 2) color.g += 100;
                        if ((adj % 3) == 1) color.r += 100;

                        if (flag) { color.r += 100; color.g += 100; color.b += 100; }

                        assert(adjacency[index] < text.length);
                        DrawText(cast(const(char)*)text[adjacency[index]], x0 + 4, y0 + 2, 20, color);
                    }
                } 
            }
        }
        if (hasGameover) {
            const char* text = "Game Over! (press 'R' to restart)\0";
            DrawText(text, 40, cast(int)height * 22 + 22, 22, Color(255, 255, 255, 255));
        }
    }
}
