const project = new Project("aura-hl");

project.addIncludeDir("../");

project.addFile("../common_c/**");
project.addFile("aura/**");

resolve(project);
