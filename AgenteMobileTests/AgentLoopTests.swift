//
//  AgentLoopTests.swift
//  AgenteMobileTests
//

import Foundation
import Testing
@testable import AgenteMobile

@MainActor
struct AgentLoopTests {

    private func makeAgent(
        _ responses: [ClaudeResponse],
        tools: [AgentTool] = [],
        maxSteps: Int = 10
    ) -> (AgentLoop, MockAnthropicRepository) {
        let repository = MockAnthropicRepository(responses: responses)
        let agent = AgentLoop(repository: repository, tools: tools, systemPrompt: "test prompt", maxSteps: maxSteps)
        return (agent, repository)
    }

    @Test func plainReplyEndsTheTurn() async throws {
        let (agent, repository) = makeAgent([.text("Hello!")])

        let (events, error) = await run(agent, "Hi")

        #expect(error == nil)
        #expect(events == [.assistantText("Hello!")])
        #expect(repository.requests.count == 1)
        #expect(repository.requests[0].system == "test prompt")
        #expect(agent.history.count == 2)
    }

    @Test func toolUseRunsTheToolAndSendsTheResultBack() async throws {
        let tool = FakeTool(result: "42")
        let (agent, repository) = makeAgent([
            .toolUse("fake_tool", id: "toolu_abc", input: ["question": .string("answer?")]),
            .text("The answer is 42.")
        ], tools: [tool])

        let (events, error) = await run(agent, "Ask the tool")

        #expect(error == nil)
        #expect(events == [
            .toolStarted(name: "fake_tool"),
            .toolFinished(name: "fake_tool", isError: false),
            .assistantText("The answer is 42.")
        ])
        #expect(try tool.calls.first?.string("question") == "answer?")

        // Every request offers the injected tools
        #expect(repository.requests.map { $0.tools.map(\.name) } == [["fake_tool"], ["fake_tool"]])

        // History: user, assistant tool_use, user tool_result
        let secondRequest = repository.requests[1].messages
        #expect(secondRequest.count == 3)
        let result = try toolResult(in: try #require(secondRequest.last))
        #expect(result["type"]?.stringValue == "tool_result")
        #expect(result["tool_use_id"]?.stringValue == "toolu_abc")
        #expect(result["content"]?.stringValue == "42")
        #expect(result["is_error"]?.boolValue == false)
    }

    @Test func failingToolIsReportedToClaudeAndTheLoopContinues() async throws {
        let (agent, repository) = makeAgent([
            .toolUse("fake_tool"),
            .text("Sorry, the disk is full.")
        ], tools: [FakeTool(fails: true)])

        let (events, error) = await run(agent, "Save it")

        #expect(error == nil)
        #expect(events.contains(.toolFinished(name: "fake_tool", isError: true)))
        #expect(events.last == .assistantText("Sorry, the disk is full."))

        let result = try toolResult(in: try #require(repository.requests[1].messages.last))
        #expect(result["is_error"]?.boolValue == true)
        #expect(result["content"]?.stringValue == "Error: disk is full")
    }

    @Test func unknownToolIsReportedToClaude() async throws {
        let (agent, repository) = makeAgent([
            .toolUse("format_disk"),
            .text("I can't do that.")
        ], tools: [FakeTool()])

        let (events, error) = await run(agent, "Format the disk")

        #expect(error == nil)
        #expect(events.contains(.toolFinished(name: "format_disk", isError: true)))
        let result = try toolResult(in: try #require(repository.requests[1].messages.last))
        #expect(result["is_error"]?.boolValue == true)
        #expect(result["content"]?.stringValue == "Error: Unknown tool 'format_disk'")
    }

    @Test func stopsAtTheStepLimit() async throws {
        let tool = FakeTool()
        let (agent, repository) = makeAgent(
            Array(repeating: .toolUse("fake_tool"), count: 3),
            tools: [tool],
            maxSteps: 3
        )

        let (_, error) = await run(agent, "Loop forever")

        #expect(error as? AgentError == .stepLimitReached(3))
        #expect(repository.requests.count == 3)
        #expect(tool.calls.count == 3)
    }

    @Test func truncatedResponseNeverRunsItsTools() async throws {
        let tool = FakeTool()
        let (agent, _) = makeAgent(
            [.toolUse("fake_tool", stopReason: "max_tokens")],
            tools: [tool]
        )

        let (events, error) = await run(agent, "Write a huge file")

        #expect(error as? AgentError == .maxTokens)
        #expect(events.isEmpty)
        #expect(tool.calls.isEmpty)
    }

    @Test func refusalStopsTheLoop() async throws {
        let (agent, _) = makeAgent([.text("I can't help with that.", stopReason: "refusal")])

        let (events, error) = await run(agent, "Something bad")

        #expect(error as? AgentError == .refusal)
        #expect(events == [.assistantText("I can't help with that.")])
    }

    @Test func historyCarriesOverToTheNextMessage() async throws {
        let (agent, repository) = makeAgent([.text("Hi!"), .text("Still here.")])

        _ = await run(agent, "Hello")
        _ = await run(agent, "Are you there?")

        // user, assistant, user
        #expect(repository.requests[1].messages.count == 3)
        #expect(agent.history.count == 4)
    }

    @Test func messageSentWhileRunningIsRejected() async throws {
        let (agent, repository) = makeAgent([.text("Hi!"), .text("Free again.")])

        let first = agent.send("Hello")
        let (_, error) = await run(agent, "Me too")
        #expect(error as? AgentError == .alreadyRunning)

        for try await _ in first {}
        #expect(repository.requests.count == 1)
        #expect(agent.history.count == 2)

        // Once the first message finishes, the loop takes new ones again
        let (_, nextError) = await run(agent, "Again")
        #expect(nextError == nil)
    }
}
