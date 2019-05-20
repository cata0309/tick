const std = @import("std");
const allocator = std.debug.global_allocator;

const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./vm.zig").OpCode;
const Token = @import("./scanner.zig").Token;
const TokenType = @import("./scanner.zig").TokenType;
const Scanner = @import("./scanner.zig").Scanner;
const Value = @import("./value.zig").Value;

pub const Parser = struct {
    current: Token,
    previous: Token,
    hadError: bool,
    hadPanic: bool,

    pub fn create() Parser {
        return Parser {
            .current = undefined,
            .previous = undefined,
            .hadError = false,
            .hadPanic = false
        };
    }

    fn errorAtCurrent(self: *Parser, message: []const u8) void {
        self.errorAt(&self.current, message);
    }

    fn errorAtPrevious(self: *Parser, message: []const u8) void {
        self.errorAt(&self.previous, message);
    }

    fn errorAt(self: *Parser, token: *Token, message: []const u8) void {
        if (self.hadPanic) return;
        self.hadPanic = true;

        std.debug.warn("[line {}] Error", token.line);

        if (token.token_type == TokenType.EOF) {
            std.debug.warn(" at end");
        } else if (token.token_type == TokenType.Error) {
            // Nothing.
        } else {
            std.debug.warn(" at '{}'", token.lexeme);
        }

        std.debug.warn(": {}\n", message);
        self.hadError = true;
    }
};

pub const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence
};

pub const ParseFn = fn(self: *Instance, canAssign: bool) void;

pub const Precedence = packed enum(u8) {
    None,
    Assignment,  // =
    Or,          // or
    And,         // and
    Equality,    // == !=
    Comparison,  // < > <= >=
    Term,        // + -
    Factor,      // * /
    Unary,       // ! - +
    Call,        // . () []
    Primary,

    fn next(current: Precedence) Precedence {
        return @intToEnum(Precedence, @enumToInt(current) + 1);
    }

    fn isLowerThan(current: Precedence, other: Precedence) bool {
        return @enumToInt(current) <= @enumToInt(other);
    }
};

fn makeRule(_: TokenType, prefix: ?ParseFn, infix: ?ParseFn, precedence: Precedence) ParseRule {
    return ParseRule {
        .prefix = prefix,
        .infix = infix,
        .precedence = precedence
    };
}

pub const Instance = struct {
    parser: Parser,
    scanner: Scanner,
    current_chunk: *Chunk,

    const rules = []ParseRule {
        makeRule(TokenType.LeftParen,    grouping, null,   Precedence.Call),
        makeRule(TokenType.RightParen,   null,     null,   Precedence.None),
        makeRule(TokenType.LeftBrace,    null,     null,   Precedence.None),
        makeRule(TokenType.RightBrace,   null,     null,   Precedence.None),
        makeRule(TokenType.Comma,        null,     null,   Precedence.None),
        makeRule(TokenType.Dot,          null,     null,   Precedence.Call),
        makeRule(TokenType.Minus,        unary,    binary, Precedence.Term),
        makeRule(TokenType.Plus,         null,     binary, Precedence.Term),
        makeRule(TokenType.Semicolon,    null,     null,   Precedence.None),
        makeRule(TokenType.Slash,        null,     binary, Precedence.Factor),
        makeRule(TokenType.Star,         null,     binary, Precedence.Factor),
        makeRule(TokenType.Bang,         unary,    null,   Precedence.None),
        makeRule(TokenType.BangEqual,    null,     binary, Precedence.Equality),
        makeRule(TokenType.Equal,        null,     null,   Precedence.None),
        makeRule(TokenType.EqualEqual,   null,     binary, Precedence.Equality),
        makeRule(TokenType.Greater,      null,     binary, Precedence.Comparison),
        makeRule(TokenType.GreaterEqual, null,     binary, Precedence.Comparison),
        makeRule(TokenType.Less,         null,     binary, Precedence.Comparison),
        makeRule(TokenType.LessEqual,    null,     binary, Precedence.Comparison),
        makeRule(TokenType.Identifier,   null,     null,   Precedence.None),
        makeRule(TokenType.String,       string,   null,   Precedence.None),
        makeRule(TokenType.Number,       number,   null,   Precedence.None),
        makeRule(TokenType.And,          null,     null,   Precedence.And),
        makeRule(TokenType.Class,        null,     null,   Precedence.None),
        makeRule(TokenType.Else,         null,     null,   Precedence.None),
        makeRule(TokenType.False,        literal,  null,   Precedence.None),
        makeRule(TokenType.Fn,           null,     null,   Precedence.None),
        makeRule(TokenType.For,          null,     null,   Precedence.None),
        makeRule(TokenType.If,           null,     null,   Precedence.None),
        makeRule(TokenType.Nil,          literal,  null,   Precedence.None),
        makeRule(TokenType.Or,           null,     null,   Precedence.Or),
        makeRule(TokenType.Print,        null,     null,   Precedence.None),
        makeRule(TokenType.Return,       null,     null,   Precedence.None),
        makeRule(TokenType.Super,        null,     null,   Precedence.None),
        makeRule(TokenType.This,         null,     null,   Precedence.None),
        makeRule(TokenType.True,         literal,  null,   Precedence.None),
        makeRule(TokenType.Var,          null,     null,   Precedence.None),
        makeRule(TokenType.While,        null,     null,   Precedence.None),
        makeRule(TokenType.Error,        null,     null,   Precedence.None),
        makeRule(TokenType.EOF,          null,     null,   Precedence.None),
    };

    pub fn create() Instance {
        return Instance {
            .parser = Parser.create(),
            .scanner = Scanner.create(),
            .current_chunk = undefined
        };
    }

    pub fn compile(self: *Instance, source: []const u8, chunk: *Chunk) bool {
        self.scanner.init(source);
        self.current_chunk = chunk;
        self.parser.hadError = false;
        self.parser.hadPanic = false;

        self.advance();

        while (!self.match(.EOF)) {
            self.declaration();
        }

        self.declaration();
        self.end();

        return !self.parser.hadError;
    }

    fn advance(self: *Instance) void {
        self.parser.previous = self.parser.current;

        while (true) {
            self.parser.current = self.scanner.scanToken();
            if (true) std.debug.warn("Scanned {}\n", @tagName(self.parser.current.token_type));
            if (self.parser.current.token_type != TokenType.Error) break;
            self.parser.errorAtCurrent(self.parser.current.lexeme);
        }
    }

    fn consume(self: *Instance, token_type: TokenType, message: []const u8) void {
        if (self.parser.current.token_type == token_type) {
            _ = self.advance();
            return;
        }

        self.parser.errorAtCurrent(message);
    }

    fn currentChunk(self: *const Instance) *Chunk {
        return self.current_chunk;
    }

    fn parseStatement(self: *Instance) void {
        if (self.match(.print)) {
            self.printStatement();
        } else {
            self.expressionStatement();
        }
    }

    fn match(self: *Instance, TokenType type) bool {
        if (!self.check(type)) return false;
        self.advance();
        return true;
    }

    fn check(self: *Instance, TokenType type) bool {
        return parser.current.type == type;
    }

    fn expressionStatement(self: *Instance) void {
        self.parseExpression();
        self.emitByte(OP_POP);
        self.consume(TOKEN_SEMICOLON, "Expect ';' after expression.");
    }

    fn printStatement(self: *Instance) void {
        self.expression();
        self.consume(TOKEN_SEMICOLON, "Expect ';' after value.");
        self.emitByte(OP_PRINT);
    }

    const declaration(self: *Instance) void {
        if (self.match(TOKEN_VAR)) {
            self.varDeclaration();
        } else {
            self.statement();
        }
        if (parser.panicMode) synchronize();
    }

    fn synchronize(self: *Instance) void {
        self.parser.panicMode = false;

        while (self.parser.current.type != TOKEN_EOF) {
            if (self.parser.previous.type == TOKEN_SEMICOLON) return;

            switch (self.parser.current.type) {
                .Class, .Fun, .Var, .For, .If, .While, .Print, .Return => return;
                else => {}
            }
            self.advance();
        }
    }

    fn parseExpression(self: *Instance) void {
       self.parsePrecedence(Precedence.Assignment);
    }

    fn  varDeclaration() void {
        uint8_t global = parseVariable("Expect variable name.");

        if (match(TOKEN_EQUAL)) {
            expression();
        } else {
            emitByte(OP_NIL);
        }
        consume(TOKEN_SEMICOLON, "Expect ';' after variable declaration.");

        defineVariable(global);
    }

    fn  parseVariable(const char* errorMessage) uint8_t {
        consume(TOKEN_IDENTIFIER, errorMessage);
        return identifierConstant(&parser.previous);
    }

    fn  identifierConstant(Token* name) uint8_t {
        return makeConstant(OBJ_VAL(copyString(name->start, name->length)));
    }

    fn  defineVariable(uint8_t global) void {
        emitBytes(OP_DEFINE_GLOBAL, global);
    }

    fn parsePrecedence(self: *Instance, precedence: Precedence) void {
        _ = self.advance();

        const parsePrefix = getRule(self.parser.previous.token_type).prefix;
        std.debug.warn("Parsing Prefix {}, Precedence {}\n", @tagName(self.parser.previous.token_type), @tagName(precedence));

        if (parsePrefix == null) {
            self.parser.errorAtCurrent("Expect expression");
            return;
        }

          bool canAssign = precedence <= PREC_ASSIGNMENT;
        prefixRule(canAssign);

        parsePrefix.?(self);

        while (precedence.isLowerThan(getRule(self.parser.current.token_type).precedence)) {
            _ = self.advance();
            const parseInfix = getRule(self.parser.previous.token_type).infix.?;
            parseInfix(self, canAssign);
        }

        if (canAssign and match(TOKEN_EQUAL)) {
            error("Invalid assignment target.");
            expression();
        }
    }

    fn getRule(token_type: TokenType) *const ParseRule {
        const rule = &rules[@enumToInt(token_type)];
        return rule;
    }

    fn grouping(self: *Instance, canAssign: bool) void {
        self.parseExpression();
        self.consume(TokenType.RightParen, "Expect ')' after expression.");
    }

    fn number(self: *Instance, canAssign: bool) void {
        const value = std.fmt.parseUnsigned(u8, self.parser.previous.lexeme, 10) catch unreachable;
        self.emitConstant(Value { .Number = @intToFloat(f64, value) });
    }

    fn unary(self: *Instance, canAssign: bool) void {
        const operator_type = self.parser.previous.token_type;

        // Compile the operand.
        self.parsePrecedence(Precedence.Unary);

        // Emit the operator instruction.
        switch (operator_type) {
            TokenType.Bang => self.emitOpCode(OpCode.Not),
            TokenType.Minus => self.emitOpCode(OpCode.Negate),
            else => unreachable
        }
    }

    fn binary(self: *Instance, canAssign: bool) void {
        // Remember the operator.
        const operator_type = self.parser.previous.token_type;

        // Compile the right operand.
        const rule = getRule(operator_type);
        self.parsePrecedence(rule.precedence.next());

        // Emit the operator instruction.
        switch (operator_type) {
            TokenType.BangEqual    => self.emitOpCodes(OpCode.Equal, OpCode.Not),
            TokenType.EqualEqual   => self.emitOpCode(OpCode.Equal),
            TokenType.Greater      => self.emitOpCode(OpCode.Greater),
            TokenType.GreaterEqual => self.emitOpCodes(OpCode.Less, OpCode.Not),
            TokenType.Less         => self.emitOpCode(OpCode.Less),
            TokenType.LessEqual    => self.emitOpCodes(OpCode.Greater, OpCode.Not),
            TokenType.Plus         => self.emitOpCode(OpCode.Add),
            TokenType.Minus        => self.emitOpCode(OpCode.Subtract),
            TokenType.Star         => self.emitOpCode(OpCode.Multiply),
            TokenType.Slash        => self.emitOpCode(OpCode.Divide),
            else => unreachable
        }
    }

    fn literal(self: *Instance, canAssign: bool) void {
        switch (self.parser.previous.token_type) {
            TokenType.False => self.emitOpCode(OpCode.False),
            TokenType.Nil => self.emitOpCode(OpCode.Nil),
            TokenType.True => self.emitOpCode(OpCode.True),
            else => unreachable
        }
    }

    fn variable(bool canAssign) void {
        self.namedVariable(parser.previous, canAssign);
    }

    fn namedVariable(Token name, bool canAssign) void {
        const arg = self.identifierConstant(&name);

        if (canAssign and self.match(TOKEN_EQUAL)) {
            self.expression();
            self.emitBytes(.SetGlobal, arg);
        } else {
            self.emitBytes(.GetGlobal, arg);
        }
    }

    fn string(self: *Instance) void {
        emitConstant(copyString(self.parser.previous.start + 1, self.parser.previous.length - 2));
    }

    fn end(self: *Instance) void {
        self.emitReturn();
        if(!self.parser.hadError) {
            self.currentChunk().disassemble("Chunk");
        }
    }

    fn emitReturn(self: *Instance) void {
        self.emitOpCode(OpCode.Return);
    }

    fn emitOpCode(self: *Instance, op: OpCode) void {
        self.emitByte(@enumToInt(op));
    }

    fn emitOpCodes(self: *Instance, op1: OpCode, op2: OpCode) void {
        self.emitByte(@enumToInt(op1));
        self.emitByte(@enumToInt(op2));
    }

    fn emitByte(self: *Instance, byte: u8) void {
        self.currentChunk().write(byte, self.parser.previous.line) catch unreachable;
    }

    fn emitBytes(self: *Instance, byte1: u8, byte2: u8) void {
        self.emitByte(byte1);
        self.emitByte(byte2);
    }

    fn emitConstant(self: *Instance, value: Value) void {
        self.emitBytes(@enumToInt(OpCode.Constant), self.makeConstant(value));
    }

    fn makeConstant(self: *Instance, value: Value) u8 {
        return self.currentChunk().addConstant(value);
    }
};
