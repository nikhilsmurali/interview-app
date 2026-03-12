$apiKey = "AIzaSyAJdmHv1nlTq1OIhXN_QFO5B_KhIj5RAtA"
$baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey"

function Test-QuestionGeneration {
    param(
        [string]$Company,
        [string]$Role
    )

    $prompt = @"
You are a senior technical interviewer at $Company hiring for the $Role position.

Generate exactly 5 strictly technical interview questions with real-world depth and practical focus.

Rules:
- Questions must test hands-on engineering knowledge, not theory definitions
- Each question must be scenario-based, implementation-focused, or debugging-oriented
- Prefer "how", "why", or "what would you do if" style questions
- Do NOT include HR, behavioral, or career questions
- Do NOT include company culture, values, strengths/weaknesses, or future plans
- Do NOT ask generic textbook questions
- Each question must reference real tools, architectures, or workflows used in $Role
- Each question must include constraints or trade-offs (performance, scalability, security, cost, UX, reliability)
- Questions should simulate real interview difficulty at a mid-to-senior engineering level

Role-specific depth requirements:

If role is Frontend:
- Cover client-side vs server-side rendering
- Browser rendering pipeline, DOM, event loop
- HTML semantics & accessibility
- CSS layout (Flexbox/Grid), performance, reflows/repaints
- State management, API integration, performance optimization

If role is Backend:
- Database connections, pooling, transactions
- Caching strategies (Redis/Memcached), cache invalidation
- API design, rate limiting, authentication
- Concurrency, async processing, performance bottlenecks
- Data consistency and failure handling

If role is Flutter:
- Widget lifecycle and rebuild optimization
- State management trade-offs (Provider, Riverpod, Bloc)
- Platform channels and native integration
- Performance profiling and frame drops
- Handling large lists, images, and background tasks

If role is DevOps:
- CI/CD pipeline design
- Containerization and orchestration
- Infrastructure as Code
- Monitoring, logging, alerting
- Scaling, failover, and incident response

Output format:
- Return only a numbered list of questions
- No explanations, no headings, no extra text
"@

    $body = @{
        contents = @(
            @{
                parts = @(
                    @{ text = $prompt }
                )
            }
        )
        safetySettings = @(
            @{ category = "HARM_CATEGORY_HARASSMENT"; threshold = "BLOCK_NONE" }
            @{ category = "HARM_CATEGORY_HATE_SPEECH"; threshold = "BLOCK_NONE" }
            @{ category = "HARM_CATEGORY_SEXUALLY_EXPLICIT"; threshold = "BLOCK_NONE" }
            @{ category = "HARM_CATEGORY_DANGEROUS_CONTENT"; threshold = "BLOCK_NONE" }
        )
    } | ConvertTo-Json -Depth 5

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Company: $Company | Role: $Role" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri $baseUrl -Method Post -Body $body -ContentType "application/json"
        $text = $response.candidates[0].content.parts[0].text
        
        Write-Host $text -ForegroundColor White

        # Parse and count questions
        $questions = $text -split "`n" | Where-Object { $_.Trim() -ne "" }
        $questionCount = ($questions | Where-Object { $_ -match '^\d+\.' }).Count
        Write-Host "`n--- Analysis ---" -ForegroundColor Yellow
        Write-Host "Questions generated: $questionCount / 5" -ForegroundColor Yellow
        
        # Check for HR/behavioral keywords
        $hrKeywords = @("strength", "weakness", "tell me about yourself", "career goal", "why do you want", "culture", "team player", "leadership style", "where do you see yourself")
        $hrFound = @()
        foreach ($kw in $hrKeywords) {
            if ($text -match $kw) {
                $hrFound += $kw
            }
        }
        if ($hrFound.Count -gt 0) {
            Write-Host "WARNING: HR/behavioral keywords detected: $($hrFound -join ', ')" -ForegroundColor Red
        } else {
            Write-Host "PASS: No HR/behavioral keywords detected" -ForegroundColor Green
        }

        # Check for technical depth keywords based on role
        $techKeywords = @()
        switch -Wildcard ($Role.ToLower()) {
            "*frontend*" { $techKeywords = @("rendering", "DOM", "CSS", "state", "API", "performance", "component", "browser") }
            "*backend*"  { $techKeywords = @("database", "cache", "API", "auth", "concurrency", "query", "server", "endpoint") }
            "*flutter*"  { $techKeywords = @("widget", "state", "Provider", "Bloc", "platform", "performance", "build", "async") }
            "*devops*"   { $techKeywords = @("CI/CD", "container", "Docker", "Kubernetes", "monitor", "deploy", "pipeline", "infra") }
            default      { $techKeywords = @("implement", "design", "optimize", "debug", "architecture", "system") }
        }
        $techFound = @()
        foreach ($kw in $techKeywords) {
            if ($text -match $kw) {
                $techFound += $kw
            }
        }
        Write-Host "Technical keywords found: $($techFound -join ', ')" -ForegroundColor Green
        Write-Host "Technical relevance: $($techFound.Count)/$($techKeywords.Count) keywords matched" -ForegroundColor Yellow

    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Test Cases ---
Write-Host "===== GEMINI QUESTION GENERATION TEST =====" -ForegroundColor Magenta
Write-Host "Testing with different company + role combos...`n" -ForegroundColor Magenta

Test-QuestionGeneration -Company "Google" -Role "Frontend Developer"
Test-QuestionGeneration -Company "Amazon" -Role "Backend Developer"
Test-QuestionGeneration -Company "Flipkart" -Role "Flutter Developer"
Test-QuestionGeneration -Company "Microsoft" -Role "DevOps Engineer"

Write-Host "`n`n===== TEST COMPLETE =====" -ForegroundColor Magenta
