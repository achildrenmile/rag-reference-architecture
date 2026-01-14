# Demo Prompt Templates

Use these prompts to showcase the capabilities of GPT4Strali.

## General Chat

### Quick Facts
```
What are the three laws of thermodynamics? Explain each one briefly.
```

### Creative Writing
```
Write a short poem about artificial intelligence helping humanity.
```

### Summarization
```
Summarize the key differences between machine learning and deep learning in 3 bullet points.
```

## Code Generation (use codellama model)

### Python Function
```
Write a Python function that validates an email address using regex. Include docstring and type hints.
```

### Debug Code
```
Find and fix the bug in this code:
def calculate_average(numbers):
    total = 0
    for num in numbers:
        total += num
    return total / len(numbers)

# Test: calculate_average([]) causes an error
```

### Code Explanation
```
Explain what this code does line by line:
[paste code here or use "Read the file /data/demo/example.py and explain what it does"]
```

## Vision/Image Analysis (use llava model)

### Image Description
```
[Upload an image] Describe what you see in this image in detail.
```

### Technical Diagram
```
[Upload a diagram] Explain the architecture shown in this diagram.
```

### OCR/Text Extraction
```
[Upload image with text] Extract and transcribe all text visible in this image.
```

## Web Search (enable DuckDuckGo tool)

### Current Events
```
Search the web for the latest news about artificial intelligence regulations in the EU.
```

### Technical Research
```
Search for best practices for securing Docker containers in production.
```

### Fact Checking
```
Search the web to verify: Is it true that the Great Wall of China is visible from space?
```

## Filesystem Operations (enable filesystem tool)

### List Files
```
List all files in the /data/demo directory and describe what each file contains.
```

### Read and Analyze
```
Read the file /data/demo/sample_data.csv and calculate the average salary by department.
```

### Create File
```
Create a new file /data/demo/notes.txt with a summary of our conversation.
```

## GitHub Operations (enable GitHub tool)

### Repository Info
```
Get information about the tensorflow/tensorflow repository on GitHub.
```

### Search Repos
```
Search GitHub for popular Python libraries for data visualization.
```

### View Issues
```
List the most recent open issues in the microsoft/vscode repository.
```

## RAG/Knowledge Base

### Document Q&A (after uploading documents)
```
#KnowledgeBaseName What are the main security recommendations mentioned in the documents?
```

### Multi-document Analysis
```
#KnowledgeBaseName Compare the approaches discussed in the uploaded documents.
```

## Combined Tool Usage

### Research Task
```
[Enable: search + filesystem]
Search the web for the current Python version, then create a file /data/demo/python_info.txt with the version number and release date.
```

### Code Review
```
[Enable: filesystem + GitHub]
Read the code in /data/demo/example.py and search GitHub for similar implementations to suggest improvements.
```
