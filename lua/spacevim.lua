local M = {}


function M.eval(l)
    if vim.api ~= nil then
        return vim.api.nvim_eval(l)
    else
        return vim.eval(l)
    end
end

if vim.command ~= nil then
    function M.cmd(command)
        return vim.command(command)
    end
else
    function M.cmd(command)
        return vim.api.nvim_command(command)
    end
end

-- there is no want to call viml function in old vim and neovim

local function build_argv(...)
    local str = ''
    for index, value in ipairs(...) do
        if str ~= '' then
            str = str .. ','
        end
        if type(value) == 'string' then
            str = str .. '"' .. value .. '"'
        elseif type(value) == 'number' then
            str = str .. value
        end
    end
    return str
end

function M.call(funcname, ...)
    if vim.call ~= nil then
        return vim.call(funcname, ...)
    else
        if vim.api ~= nil then
            return vim.api.nvim_call_function(funcname, {...})
        else
            -- call not call vim script function in lua
            vim.command('let g:lua_rst = ' .. funcname .. '(' .. build_argv({...}) .. ')')
            return M.eval('g:lua_rst')
        end
    end
end

-- this is for Vim and old neovim
M.fn = setmetatable({}, {
        __index = function(t, key)
            local _fn
            if vim.api ~= nil and vim.api[key] ~= nil then
                _fn = function()
                    error(string.format("Tried to call API function with vim.fn: use vim.api.%s instead", key))
                end
            else
                _fn = function(...)
                    return M.call(key, ...)
                end
            end
            t[key] = _fn
            return _fn
        end
    })

-- This is for vim and old neovim to use vim.o
M.vim_options = setmetatable({}, {
        __index = function(t, key)
            local _fn
            if vim.api ~= nil then
                -- for neovim
                return vim.api.nvim_get_option(key)
            else
                -- for vim
                _fn = M.eval('&' .. key)
            end
            t[key] = _fn
            return _fn
        end
    })

-- this function is only for vim
function M.has(feature)
    return M.eval('float2nr(has("' .. feature .. '"))')
end

function M.echo(msg)
    if vim.api ~= nil then
        vim.api.nvim_echo({{msg}}, false, {})
    else
        vim.command('echo ' .. build_argv({msg}))
    end
end

if vim.g.neovide then
    -- 1. Cmd + C 在可视模式（Visual）下复制选中文件到系统剪切板
    vim.keymap.set('v', '<D-c>', '"+y', { desc = "复制到系统剪切板" })

    vim.keymap.set({'n', 'v', 'i'}, '<D-o>', function()
        vim.cmd('stopinsert')
        -- 调用 Mac 底层 AppleScript 唤起选择框
        local handle = io.popen([[osascript -e 'POSIX path of (choose file with prompt "选择要用 Neovide 打开的文件:")' 2>/dev/null]])
        if handle then
            local result = handle:read("*a")
            handle:close()
            -- 如果用户正常选择了解压路径（去除了尾部换行符）
            if result and result ~= "" then
                local file_path = result:gsub("%s+$", "")
                -- 在 Neovim 中打开该文件
                vim.cmd('edit ' .. vim.fn.fnameescape(file_path))
            end
        end
    end, { desc = "通过AppleScript打开Mac原生文件窗口" })

      -- 支持在 普通、插入、可视、命令行、终端模式下用 Cmd+V 粘贴
    vim.keymap.set({'n', 'i', 'v', 'c', 't'}, '<D-v>', function()
        vim.api.nvim_paste(vim.fn.getreg('+'), true, -1)
    end, { desc = "从系统剪切板粘贴" }) 


    -- 1. Cmd + T 创建新标签页（在所有模式下均可直接触发）
    vim.keymap.set({'n', 'v', 'i'}, '<D-t>', function()
        vim.cmd('stopinsert') -- 如果在插入模式，先安全退出
        vim.cmd('tabnew')     -- 创建空白新标签页
    end, { desc = "新建标签页" })

      -- ==================== 安全关闭标签/分屏 (Cmd + W) ====================
    vim.keymap.set({'n', 'v', 'i'}, '<D-w>', function()
        vim.cmd('stopinsert') -- 如果在插入模式，先安全退出

        -- 1. 检查当前缓冲区（Buffer）是否有未保存的修改
        if vim.api.nvim_get_option_value('modified', { buf = 0 }) then
            -- 如果有未保存的文件，使用 Neovim 内置的确认弹窗（支持鼠标点击和键盘选择）
            -- 按钮顺序：1.保存并关闭  2.放弃修改并关闭  3.取消操作
            local choice = vim.fn.confirm("文件尚未保存！要如何处理？", "&Save\n&Discard\n&Cancel", 3)
            
            if choice == 1 then
                -- 用户选择：保存并继续
                local success, _ = pcall(vim.cmd, 'write')
                if not success then
                    print("保存失败，放弃关闭操作！")
                    return -- 如果保存失败（如无权限/无文件名），强制不关闭
                end
            elseif choice == 2 then
                -- 用户选择：放弃修改，强制关闭当前窗口/缓冲区
                vim.cmd('setnomodified') -- 标记为未修改，允许接下来的关闭逻辑
            else
                -- 用户选择：取消，或者直接关闭了弹窗，则什么都不做（强制不关闭）
                print("已取消关闭操作")
                return
            end
        end

        -- 2. 核心关闭逻辑（文件已保存，或者用户同意放弃修改后才会走到这里）
        local win_count = #vim.api.nvim_tabpage_list_wins(0)
        local tab_count = #vim.api.nvim_list_tabpages()

        if win_count > 1 then
            -- 如果当前标签页里有分割出来的分屏（Split），只关闭当前分屏
            vim.cmd('close')
        elseif tab_count > 1 then
            -- 如果只有一个分屏，但有多个标签页，则关闭当前标签页
            vim.cmd('tabclose')
        else
            -- 如果是最后一个标签页里的最后一个窗口，安全退出整个 Neovide
            vim.cmd('quit') 
        end
    end, { desc = "安全关闭当前分屏或标签页" })

end

return M
