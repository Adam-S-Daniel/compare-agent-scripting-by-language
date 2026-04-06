DOTNET = $(HOME)/.dotnet/dotnet

.PHONY: test run clean

test:
	$(DOTNET) test MatrixGenerator.Tests --verbosity normal

run:
	$(DOTNET) run MatrixGenerator.cs sample-config.json

clean:
	rm -rf MatrixGenerator.Tests/bin MatrixGenerator.Tests/obj
