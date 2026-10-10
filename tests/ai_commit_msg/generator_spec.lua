describe("generator", function()
  local generator
  local original_notify
  local original_schedule
  local original_system
  local original_providers
  local notifications

  before_each(function()
    package.loaded["ai_commit_msg.generator"] = nil
    generator = require("ai_commit_msg.generator")
    original_notify = vim.notify
    original_schedule = vim.schedule
    original_system = vim.system
    original_providers = package.loaded["ai_commit_msg.providers"]

    notifications = {}
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
    vim.schedule = function(callback)
      callback()
    end
    vim.system = function(command, _, callback)
      if command[2] == "diff" then
        callback({ code = 0, stdout = "+new line", stderr = "" })
      else
        callback({ code = 0, stdout = "", stderr = "" })
      end
    end
    package.loaded["ai_commit_msg.providers"] = {
      call_api = function(_, _, callback)
        callback(false, "API exploded")
      end,
    }
  end)

  after_each(function()
    vim.notify = original_notify
    vim.schedule = original_schedule
    vim.system = original_system
    package.loaded["ai_commit_msg.providers"] = original_providers
  end)

  local function error_notifications()
    return vim.tbl_filter(function(n)
      return n.level == vim.log.levels.ERROR
    end, notifications)
  end

  it("reports a provider error once when notifications are enabled", function()
    generator.generate({ notifications = true, spinner = false, system_prompt = "" })

    local errors = error_notifications()
    assert.equals(1, #errors)
    assert.equals("❌ API exploded", errors[1].msg)
  end)

  it("still reports a provider error when notifications are disabled", function()
    generator.generate({ notifications = false, spinner = false, system_prompt = "" })

    local errors = error_notifications()
    assert.equals(1, #errors)
    assert.equals("ai-commit-msg.nvim: API exploded", errors[1].msg)
  end)
end)
