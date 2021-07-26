from PIL import Image
import numpy as np
import dlr

def softmax(x):
    """Compute softmax values for each sets of scores in x."""
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum()

input_image = Image.open('dog.jpg').resize((224,224))
input_matrix = (np.array(input_image) / 255 - [0.485, 0.456, 0.406])/[0.229, 0.224, 0.225]
transposed = np.transpose(input_matrix, (2, 0, 1))
model = dlr.DLRModel('./model', 'cpu', 0)
res = softmax(model.run(transposed)[0][0])
pred = np.argmax(res)
prob = res[pred]
print(pred, prob)