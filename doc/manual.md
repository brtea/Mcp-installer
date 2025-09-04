### MCP 서버의 설치

-   서버에 npm, pip 등을 이용하여 설치해야 한다.

### MCP 설정 파일

-   보통 JSON 파일로 되어 있다.
-   클로드CLI, IDE등이 설치되어 있는 MCP 서버를 어떻게 이용 할 수 있는지에 관련된 설정파일이다.

### 내가 만든 mcp-installer.py

-   MCP 서버를 설치한다.
-   MCP 설정 파일을 알려줘 클로드코드 CLI 또는 IDE의 설정 파일에 기록하게 한다.
-   원래는 클로드코드 CLI 설정을 직접 열어야 하는 이 부분을 자연어 방식으로 도와준다.

### MCP 서버의 설치와 IDE에서 인식시키는 순서와 방법

1. MCP 서버를 설치한다. 터미널에서 설치한다.
2. mcp-installer. py에게 MCP 설정 파일을 알려주며 클로드코드에서 사용할수 있게 설정하라고 한다.

### MCP 서버의 설치 - npm, pip 로 설치

### MCP 설정 파일의 등록 자연어 명령어

내가 만든 mcp-installer.py에 자연어로 아래와 같이 알려줄 수 있다.

=="MCP서버를 이미 설치하였고, 여기 Json 파일이 있으니 @mcp-installer.py를 통하여 설정을 등록하라"==

### MCP 활성화 상태 확인하는 자연어 명령어

등록되어 있는 MCP 클로드코드CLI 또는 IDE에서 자연어로 아래와 같이 알려주면 등록된 MCP의 활성화 상태를 알려준다.

=="등록되어 활성화 되어 있는 MCP를 @mcp-status.py를 이용하여 상태를 확인하라"==

### 글라마 Ai의 MCP

[https://glama.ai/mcp](https://glama.ai/mcp)

![](MCP설정.png)
