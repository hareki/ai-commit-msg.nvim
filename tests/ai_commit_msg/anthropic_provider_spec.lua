describe("anthropic provider", function()
  local anthropic_provider
  local original_getenv
  local original_system

  local function respond_with(response)
    vim.system = function(_, _, callback)
      callback({ code = 0, stdout = vim.json.encode(response), stderr = "" })
    end
  end

  local function call()
    local success, message, usage
    anthropic_provider.call_api(
      { model = "claude-haiku-5-5", max_tokens = 1000, prompt = "{diff}", system_prompt = "" },
      "+new line",
      function(result_success, result_message, result_usage)
        success = result_success
        message = result_message
        usage = result_usage
      end
    )
    return success, message, usage
  end

  before_each(function()
    package.loaded["ai_commit_msg.providers.anthropic"] = nil
    anthropic_provider = require("ai_commit_msg.providers.anthropic")
    original_getenv = os.getenv
    original_system = vim.system
    os.getenv = function(key)
      if key == "ANTHROPIC_API_KEY" then
        return "test-key"
      end
      return original_getenv(key)
    end
  end)

  after_each(function()
    os.getenv = original_getenv
    vim.system = original_system
  end)

  it("reads the text block after leading thinking blocks", function()
    respond_with({
      content = {
        { type = "thinking", thinking = "", signature = "sig" },
        { type = "text", text = "feat(api): support thinking models" },
      },
      stop_reason = "end_turn",
      usage = { input_tokens = 10, output_tokens = 20 },
    })

    local success, message, usage = call()

    assert.is_true(success)
    assert.equals("feat(api): support thinking models", message)
    assert.same({ input_tokens = 10, output_tokens = 20 }, usage)
  end)

  it("reports the stop reason when the response has no text block", function()
    respond_with({
      content = { { type = "thinking", thinking = "", signature = "sig" } },
      stop_reason = "max_tokens",
    })

    local success, message = call()

    assert.is_false(success)
    assert.equals("No text in API response (stop_reason: max_tokens)", message)
  end)
end)
